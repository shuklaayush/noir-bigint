## PrimeField

A structure representing a prime field element.

The `PrimeField` structure encapsulates operations in a prime field using the Montgomery form. This form represents a field element `a` as `a.R mod p`, where `R = 2^{MAX_BITS}`. 

The structure provides efficient arithmetic operations in the prime field, leveraging the properties of the Montgomery form.

### Fields

- `val: BigUint56`: The value of the prime field element.

### Methods

- **modulus() -> Self**  
  Returns the prime field modulus.

- **R() -> Self**  
  Returns R which represents `2^{BITS_PER_LIMB*NUM_LIMBS} mod p` or `2^280 mod p`.

- **R2() -> Self**  
  Returns R^2 mod p.

- **P_INV() -> u56**  
  Returns INV which represents `-p^{-1} mod 2^{BITS_PER_LIMB}` or `-p^{-1} mod 2^56`.

- **from_raw_limbs(limbs: [u56; NUM_LIMBS]) -> Self**  
  Constructs a prime field element from raw limbs without converting to Montgomery form.

- **from_limbs(limbs: [u56; NUM_LIMBS]) -> Self**  
  Constructs a prime field element from limbs, then converts it to Montgomery form.

- **from_u56(val: u56) -> Self**  
  Constructs a prime field element from a u56 value, then converts it to Montgomery form.

- **from_biguint56(val: BigUint56) -> Self**  
  Constructs a prime field element from a BigUint56 value, then converts it to Montgomery form.

- **from_bytes(bytes: [u8]) -> Self**  
  Constructs a prime field element from a byte array, then converts it to Montgomery form.

- **to_biguint56(self: Self) -> BigUint56**  
  Converts the prime field element to a BigUint56 value.

- **to_bytes(self: Self) -> [u8; MAX_BYTES]**  
  Converts the prime field element to a byte array in little-endian byte order.

- **to_bits(self: Self) -> [u1; MAX_BITS]**  
  Converts the prime field element to a bit array, with LSB at index 0.

- **zero() -> Self**  
  Returns zero, the additive identity for the prime field.

- **one() -> Self**  
  Returns one, the multiplicative identity for the prime field.

- **neg(self: Self) -> Self**  
  Negates the prime field element.

- **add(self: Self, rhs: Self) -> Self**  
  Adds another prime field element to this one.

- **sub(self: Self, rhs: Self) -> Self**  
  Subtracts another prime field element from this one.

- **double(self: Self) -> Self**  
  Doubles the value of the prime field element.

- **mul(self: Self, other: Self) -> Self**  
  Multiplies another prime field element with this one.

- **square(self: Self) -> Self**  
  Squares the value of the prime field element.

- **montgomery_reduce(lo: BigUint56, hi: BigUint56) -> Self**  
  Reduces the value of the prime field element using the Montgomery reduction method.

- **pow(self: Self, by: BigUint56) -> Self**  
  Exponentiates the prime field element to a given BigUint56 value using the double-and-add algorithm.

- **pow_unc(self: Self, by: BigUint56) -> Self**  
  Exponentiates the prime field element without constraints.

- **invert(self: Self) -> Self**  
  Computes the multiplicative inverse of this element. Returns an error if the element is zero.

- **is_zero(self: Self) -> bool**  
  Checks if the prime field element is zero.

- **is_one(self: Self) -> bool**  
  Checks if the prime field element is one.

- **eq(self: Self, other: Self) -> bool**  
  Checks if this prime field element is equal to another.

- **println(self: Self)**  
  Prints the prime field element as a byte array.
