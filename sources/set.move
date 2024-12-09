module move_ds::set {
    use aptos_std::table::{Self, Table};
    use std::vector;

    /// Key not found in the set
    const E_NOT_FOUND: u64 = 1;
    /// Key already exists in the set
    const E_ALREADY_EXIST: u64 = 2;

    struct Set<K: copy + drop, phantom V> has store {
        keys: vector<K>,
        elems: Table<K, V>,
        size: u64
    }

    /// Create a new Set.
    public fun new<K: copy + drop, V: store>(): Set<K,V> {
        Set {
            keys: vector::empty<K>(),
            elems: table::new<K, V>(),
            size: 0
        }
    }

    /// Add a new element to the set.
    /// Aborts if the element already exists
    public fun add<K: copy + drop, V>(self: &mut Set<K,V>, key: K, value: V) {
        assert!(!contains(self, key), E_ALREADY_EXIST);
        vector::push_back(&mut self.keys, key);
        table::add(&mut self.elems, key, value);
        self.size += 1;
    }

    /// Returns true iff `set` contains an entry for `key`.
    public fun contains<K: copy + drop, V>(self: &Set<K,V>, key: K): bool {
        table::contains(&self.elems, key)
    }

    /// Removes all elements from the set
    public fun empty<K: copy + drop, V: drop>(self: &mut Set<K,V>) {
        while (self.size != 0) {
            table::remove(&mut self.elems, vector::pop_back(&mut self.keys));
            self.size -= 1;
        }
    }

    /// Insert the pair (`key`, `value`) if there is no entry for `key`,
    /// update the value of the entry for `key` to `value` otherwise.
    public fun upsert<K: copy + drop, V: drop>(self: &mut Set<K, V>, key: K, value: V) {
        if (!table::contains(&self.elems, key)) {
            // New entry - add to both vector and table
            vector::push_back(&mut self.keys, key);
            table::add(&mut self.elems, key, value);
            self.size = self.size + 1;
        } else {
            // Existing entry - just update the table value
            let ref = table::borrow_mut(&mut self.elems, key);
            *ref = value;
        };
    }

    /// Immutably borrows the value associated with the key in the set.
    /// Aborts if key is not present.
    public fun borrow<K: copy + drop, V>(self: &Set<K,V>, key: K): &V {
        table::borrow(&self.elems, key)
    }

    /// Mutably borrows the value associated with the key in the set.
    /// Aborts if key is not present.
    public fun borrow_mut<K: copy + drop, V>(self: &mut Set<K,V>, key: K): &mut V {
        table::borrow_mut(&mut self.elems, key)
    }

    /// Immutably borrows the value associated with the key in the set.
    /// Returns the default value if key is not present.
    public fun borrow_with_default<K: copy + drop, V>(
        self: &Set<K,V>,
        key: K,
        default: &V
    ): &V {
        table::borrow_with_default(&self.elems, key, default)
    }

    /// Mutably borrows the value associated with the key in the set.
    /// Adds the default value first if key is not present.
    public fun borrow_mut_with_default<K: copy + drop, V: drop>(
        self: &mut Set<K,V>,
        key: K,
        default: V
    ): &mut V {
        if (!contains(self, key)) {
            add(self, key, default);
        };
        table::borrow_mut(&mut self.elems, key)
    }

    /// Apply the function to each element in the set in original order, consuming it.
    public inline fun for_each<K: copy + drop, V>(
        self: Set<K, V>,
        f: |K, V|
    ): Set<K,V> {
        // First reverse the keys vector to consume it efficiently
        vector::reverse(&mut self.keys);
        for_each_reverse(self, |k, v| f(k, v))
    }

    /// Iterates over elements in reverse, returning both the key and its value from the table.
    public inline fun for_each_reverse<K: copy + drop, V>(
        self: Set<K, V>,
        f: |K, V|
    ): Set<K,V> {
        while (self.size > 0) {
            let key = vector::pop_back(&mut self.keys);
            let value = table::remove(&mut self.elems, key);
            f(key, value);
            self.size = self.size - 1;
        };
        self
    }

    /// Apply the function to a reference of each element in the vector.
    public inline fun for_each_ref<K: copy + drop, V>(
        self: &Set<K, V>,
        f: |&K, &V|
    ){
        let i = 0;
        let len = self.size;
        while (i < len) {
            let key = vector::borrow(&self.keys, i);
            let value = table::borrow(&self.elems, *key);
            f(key, value);
            i += 1
        };
    }

    /// Remove the key and its associated value from the set.
    /// This operation is O(1) but does not preserve the ordering of keys.
    /// Aborts if there is no entry for `key`.
    public fun remove<K: copy + drop, V>(self: &mut Set<K, V>, key: K): V {
        assert!(contains(self, key), E_NOT_FOUND);
        // First remove the value from table
        let value = table::remove(&mut self.elems, key);
        // Find key's index in vector - we know it exists since table::remove succeeded
        let i = 0;
        let len = vector::length(&self.keys);
        while (i < len) {
            if (*vector::borrow(&self.keys, i) == key) {
                break
            };
            i += 1;
        };
        // Remove key from vector using swap_remove
        vector::swap_remove(&mut self.keys, i);
        // Update size
        self.size -= 1;
        value
    }

    #[test_only]
    struct SetHolder<K: copy + drop, phantom V: drop> has key {
        t: Set<K, V>
    }

    #[test(account = @0x101)]
    fun test_upsert(account: signer) {
        let t = new<u64, u8>();
        let key: u64 = 111;
        let error_code: u64 = 1;
        assert!(!contains(&t, key), error_code);
        upsert(&mut t, key, 12);
        assert!(*borrow(&t, key) == 12, error_code);
        upsert(&mut t, key, 23);
        assert!(*borrow(&t, key) == 23, error_code);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_basic_operations(account: signer) {
        let t = new<u64, u8>();

        // Test new and empty set
        assert!(t.size == 0, 1);
        assert!(vector::length(&t.keys) == 0, 1);

        // Test add and contains
        add(&mut t, 1, 10);
        assert!(contains(&t, 1), 2);
        assert!(*borrow(&t, 1) == 10, 2);
        assert!(t.size == 1, 2);

        // Test borrow and borrow_mut
        let ref = borrow_mut(&mut t, 1);
        *ref = 20;
        assert!(*borrow(&t, 1) == 20, 3);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_empty_set(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 2, 20);
        assert!(t.size == 2, 1);

        empty(&mut t);
        assert!(t.size == 0, 2);
        assert!(!contains(&t, 1), 3);
        assert!(!contains(&t, 2), 4);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_borrow_with_default(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);

        let default_value: u8 = 100;
        assert!(*borrow_with_default(&t, 1, &default_value) == 10, 1);
        assert!(*borrow_with_default(&t, 2, &default_value) == default_value, 2);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_borrow_mut_with_default(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);

        let ref = borrow_mut_with_default(&mut t, 2, 20);
        *ref = 30;
        assert!(*borrow(&t, 2) == 30, 1);
        assert!(t.size == 2, 2);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_remove(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 2, 20);
        add(&mut t, 3, 30);

        let removed_value = remove(&mut t, 2);
        assert!(removed_value == 20, 1);
        assert!(!contains(&t, 2), 2);
        assert!(t.size == 2, 3);
        assert!(vector::length(&t.keys) == 2, 4);
        assert!(contains(&t, 1), 5);
        assert!(contains(&t, 3), 6);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_for_each(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 2, 20);
        add(&mut t, 3, 30);

        let sum = 0;
        let empty = for_each(t, |_k, v| {
            sum = sum + (v as u64);
        });
        assert!(sum == 60, 1);


        move_to(&account, SetHolder { t: empty });
    }

    #[test(account = @0x101)]
    fun test_for_each_reverse(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 2, 20);
        add(&mut t, 3, 30);

        let sum = 0;
        let empty = for_each_reverse(t, |_k, v| {
            sum = sum + (v as u64);
        });
        assert!(sum == 60, 1);
        move_to(&account, SetHolder { t: empty });
    }

    #[test(account = @0x101)]
    fun test_for_each_ref(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 2, 20);
        add(&mut t, 3, 30);

        let sum = 0;
        let keys_sum = 0;
        for_each_ref(&t, |k, v| {
            sum = sum + (*v as u64);
            keys_sum = keys_sum + *k;
        });
        assert!(sum == 60, 1);
        assert!(keys_sum == 6, 2);
        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_comprehensive_upsert(account: signer) {
        let t = new<u64, u8>();

        // Test inserting new value
        upsert(&mut t, 1, 10);
        assert!(*borrow(&t, 1) == 10, 1);
        assert!(t.size == 1, 2);

        // Test updating existing value
        upsert(&mut t, 1, 20);
        assert!(*borrow(&t, 1) == 20, 3);
        assert!(t.size == 1, 4);

        // Test multiple upserts
        upsert(&mut t, 2, 30);
        upsert(&mut t, 3, 40);
        assert!(t.size == 3, 5);

        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    #[expected_failure(abort_code = 1, location = set)] // E_NOT_FOUND = 2
    fun test_remove_nonexistent(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        remove(&mut t, 2); // Should abort since key 2 doesn't exist
        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    #[expected_failure(abort_code = 2, location = set)] // E_ALREADY_EXIST = 2
    fun test_add_duplicate(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);
        add(&mut t, 1, 20); // Should abort with E_ALREADY_EXIST
        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    #[expected_failure]
    fun test_borrow_nonexistent(account: signer) {
        let t = new<u64, u8>();
        let _value = borrow(&t, 1); // Should abort since key 1 doesn't exist
        move_to(&account, SetHolder { t });
    }

    #[test(account = @0x101)]
    fun test_borrow_mut_with_default_existing(account: signer) {
        let t = new<u64, u8>();
        add(&mut t, 1, 10);

        // Try borrow_mut_with_default on existing key
        let ref = borrow_mut_with_default(&mut t, 1, 20);
        *ref = 30;
        assert!(*borrow(&t, 1) == 30, 1);
        assert!(t.size == 1, 2); // Size shouldn't change

        move_to(&account, SetHolder { t });
    }

}