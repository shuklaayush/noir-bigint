# Noir BigInt

[![CI][ci-shield]][ci-url]
[![MIT License][license-shield]][license-url]

## Packages

This library provides three crates:

- `biguint` - custom unsigned big integer type implemented using u56 limbs 
- `primefield` - wrapper around `biguint` that implements prime field operations
- `curves` - example elliptic curve libraries built using the `primefield` type

### `biguint`

This crate provides a custom [`BigUint56`](./crates/biguint/src/lib.nr) data type, allowing for computations on large unsigned integers. The integers are represented with a fixed number of limbs, each of which is a 56-bit unsigned integer.

We utilize `u56` limbs for two primary reasons:

1. 56 is divisible by 8, simplifying conversions to/from bytes.
2. Multiplication requires a double-width intermediate value and `u112` is the maximum double-width value that can be represented in Noir.

This provides various functionalities such as arithmetic operations (addition, subtraction, multiplication, division), bitwise operations (left shift, right shift), comparisons and conversions (to bytes, to bits).

### `primefield`

This contains the [`PrimeField`](./crates/biguint/src/lib.nr) data type, which allows for efficient operations on prime field elements. This is implemented as a wrapper around the `BigUint56` type and stores the values in the [Montgomery form](https://en.wikipedia.org/wiki/Montgomery_modular_multiplication) for efficient modular multiplication/reduction.

### `curves`

This crate contains examples of the `secp256k1` and the `ed25519` curves implemented using the `PrimeField` type.

## Installation

In your `Nargo.toml` file, add the following dependency:

```toml
[dependencies]
noir_bigint = { tag = "v0.1.0", git = "https://github.com/shuklaayush/noir-bigint" }
```

## Testing

Tests are run using [`nargo`](https://noir-lang.org/dev/getting_started/nargo_installation/):

```bash
nargo test
```

All tests are run as part of the CI pipeline [`test.yaml`](./.github/workflows/test.yaml).

## Contributing

Contributions are welcome! Please adhere to the following guidelines:

- Open a pull request with a clear description of your changes.
- Changes should aim to improve code efficiency or readability.
- Add appropriate tests, ensuring all pass before submission.

## Acknowledgements

- Original [noir-bigint](https://github.com/okuyiga/noir-bigint)
- Rust [crypto-bigint](https://github.com/RustCrypto/crypto-bigint)
- Rust [num-bigint](https://github.com/rust-num/num-bigint)

## Disclaimer

This is **experimental software** and is provided on an "as is" and "as available" basis. We **do not give any warranties** and **will not be liable for any losses** incurred through any use of this code base.

[ci-shield]: https://img.shields.io/github/actions/workflow/status/shuklaayush/noir-bigint/test.yaml?branch=main&label=tests
[ci-url]: https://github.com/shuklaayush/noir-bigint/actions/workflows/test.yaml

[license-shield]: https://img.shields.io/badge/License-MIT-green.svg
[license-url]: https://github.com/shuklaayush/noir-bigint/blob/main/LICENSE
