# move-ds

A collection of efficient data structures implemented in Aptos Move.

## Data Structures

Currently available:
- `Set<K, V>`: A key-value set with O(1) operations for lookup, insertion, and removal.

## Usage

Add to your `Move.toml`:
```toml
[dependencies]
MoveDS = { git = "https://github.com/0xAnto/move-ds.git" }
rev = "mainnet" // main, mainnet, testnet
```

Example using Set:
```move
use move_ds::set;

// Create a new set
let my_set = set::new<u64, u8>();

// Add elements
set::add(&mut my_set, 1, 10);

// Check if element exists
assert!(set::contains(&my_set, 1), 1);

// Remove element
let value = set::remove(&mut my_set, 1);
```

## Testing

```bash
aptos move test --move-2
```

## Contributing

Feel free to contribute by submitting pull requests. Ensure your code is well-tested and documented.
