use dep::std::println;
use crate::{BigUint56, NUM_LIMBS, BITS_PER_LIMB, MAX_BITS, MAX_BYTES, utils};

// Prime field element
struct PrimeField {
    val: BigUint56
}

// Represents a prime field element in Montgomery form
// Montgomery form is a representation of a field element `a` as
// `a.R mod p`, where `R = 2^{MAX_BITS}`.
impl PrimeField {
    ///////////////////////////////////////////////////////////////////////////
    // FIELD SPECIFIC CONSTANTS: BN254
    ///////////////////////////////////////////////////////////////////////////

    // Prime field modulus
    fn modulus() -> Self {
        let val = BigUint56 { limbs: [0x208c16d87cfd47, 0x6a916871ca8d3c, 0xb68181585d9781, 0xe131a029b85045, 0x30644e72] };
        Self { val }
    }

    // R = 2^{BITS_PER_LIMB*NUM_LIMBS} mod p
    //   = 2^280 mod p
    fn R() -> Self {
        let val = BigUint56 { limbs: [0x6a56a28a0e0d96, 0x1e6c92b56d8f97, 0x10581c8ee608fc, 0x8c59c9e89f6e5c, 0x07359fa8] };
        Self { val }
    }

    // R^2 mod p
    fn R2() -> Self {
        let val = BigUint56 { limbs: [0xbb888f34693c46, 0x1c4bb9be2ac0dd, 0xc1a7aec3d9e1b9, 0x3cb4fa22c83580, 0x095e2ea9] };
        Self { val }
    }

    // INV = -p^{-1} mod 2^{BITS_PER_LIMB}
    //     = -p^{-1} mod 2^56
    fn P_INV() -> u56 {
        0xd20782e4866389
    }

    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    // No montgomery mul here.
    fn from_raw_limbs(limbs: [u56; NUM_LIMBS]) -> Self {
        Self { val: BigUint56{ limbs } }
    }

    fn from_limbs(limbs: [u56; NUM_LIMBS]) -> Self {
        let tmp = Self { val: BigUint56{ limbs } };

        tmp.mul(PrimeField::R2())
    }

    fn from_u56(val: u56) -> Self {
        let tmp = Self { val: BigUint56::from_u56(val) };

        // Convert to Montgomery form by computing
        // (a.R^0 * R^2) / R = a.R
        tmp.mul(PrimeField::R2())
    }

    fn from_biguint56(val: BigUint56) -> Self {
        let tmp = Self { val };

        // Convert to Montgomery form by computing
        // (a.R^0 * R^2) / R = a.R
        tmp.mul(PrimeField::R2())
    }

    fn from_bytes(bytes: [u8]) -> Self {
        let tmp = Self { val: BigUint56::from_bytes(bytes) };

        // TODO: Do I need to check this?
        // Check that tmp < p
        let modulus = PrimeField::modulus();
        assert(tmp.val.lt(modulus.val));

        // Convert to Montgomery form by computing
        // (a.R^0 * R^2) / R = a.R
        tmp.mul(PrimeField::R2())
    }

    fn to_biguint56(self: Self) -> BigUint56 {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = PrimeField::montgomery_reduce(self.val, BigUint56::zero());
        tmp.val
    }

    // Converts a field element into a byte representation in
    // little-endian byte order.
    fn to_bytes(self: Self) -> [u8; MAX_BYTES] {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = PrimeField::montgomery_reduce(self.val, BigUint56::zero());
        tmp.val.to_bytes()
    }

    // Converts a field element into a bit representation
    fn to_bits(self: Self) -> [u1; MAX_BITS] {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = PrimeField::montgomery_reduce(self.val, BigUint56::zero());
        tmp.val.to_bits()
    }

    // Returns zero, the additive identity.
    fn zero() -> Self {
        let val: BigUint56 = BigUint56::zero();
        Self { val }
    }

    // Returns one, the multiplicative identity.
    fn one() -> Self {
        PrimeField::R()
    }

    // Negates `self`.
    fn neg(self: Self) -> Self {
        if self.is_zero() {
            self
        } else {
            // Subtract `self` from `MODULUS` to negate
            let modulus = PrimeField::modulus().val;
            Self { val: modulus.sub(self.val) }
        }
    }

    // Adds `rhs` to `self`, returning the result.
    fn add(self: Self, rhs: Self) -> Self {
        let (sum, carry) = self.val.adc(rhs.val);

        let modulus = PrimeField::modulus().val;
        if ((carry == 0) & sum.lt(modulus)) {
            Self { val: sum }
        } else {
            Self { val: sum.sub(modulus) }
        }
    }

    // Subtracts `rhs` from `self`, returning the result.
    fn sub(self: Self, rhs: Self) -> Self {
        let (diff, borrow) = self.val.sbb(rhs.val);
        // If underflow occurred on the final limb, borrow = 0xfff...fff, otherwise
        // borrow = 0x000...000. Thus, we use it as a mask to conditionally add the modulus.
        if borrow == 0 {
            Self { val: diff }
        } else {
            let modulus = PrimeField::modulus().val;
            Self { val: diff.add(modulus) }
        }
    }

    // Doubles this field element.
    fn double(self: Self) -> Self {
        self.add(self)
    }

    // Multiplies `rhs` by `self`, returning the result.
    fn mul(self: Self, other: Self) -> Self {
        let (lo, hi) = self.val.mul(other.val);

        PrimeField::montgomery_reduce(lo, hi)
    }

    // Squares this element.
    // TODO: See if more efficient squaring is possible.
    fn square(self: Self) -> Self {
        self.mul(self)
    }

    fn montgomery_reduce(lo: BigUint56, hi: BigUint56) -> Self {
        let mut tmp = [0 as u56; 2*NUM_LIMBS];
        for i in 0..NUM_LIMBS {
            tmp[i] = lo.limbs[i];
            tmp[i + NUM_LIMBS] = hi.limbs[i];
        }

        let modulus = PrimeField::modulus().val;

        let mut carry2 = 0;
        for i in 0..NUM_LIMBS {
            let k = tmp[i] * PrimeField::P_INV();
            let mut carry = 0;
            for j in 0..NUM_LIMBS {
                let (prod, c) = utils::mac(tmp[i + j], k, modulus.limbs[j], carry);
                tmp[i + j] = prod;
                carry = c;
            }

            let (sum, c) = utils::adc(tmp[i + NUM_LIMBS], carry2, carry);
            tmp[i + NUM_LIMBS] = sum;
            carry2 = c;
        }

        let mut limbs = [0; NUM_LIMBS];
        for i in 0..NUM_LIMBS {
            limbs[i] = tmp[i + NUM_LIMBS];
        }

        let val = BigUint56{ limbs };
        if val.gte(modulus) {
            Self { val: val.sub(modulus) }
        } else {
            Self { val }
        }
    }

    // Exponentiates `self` by `by`.
    // Double-and-add algorithm
    fn pow(self: Self, by: BigUint56) -> Self {
        let mut res = PrimeField::one();
        for i in 0..NUM_LIMBS {
            for j in 0..BITS_PER_LIMB {
                res = res.square();
                
                if ((by.limbs[NUM_LIMBS - i - 1] >> ((BITS_PER_LIMB - j - 1) as u56)) & 1) == 1 {
                    res = res.mul(self);
                }
            }
        }
        res
    }

    unconstrained fn pow_unc(self: Self, by: BigUint56) -> Self {
        self.pow(by)
    }

    // Computes the multiplicative inverse of this element,
    // failing if the element is zero.
    fn invert(self: Self) -> Self {
        assert(!self.is_zero());

        let inv = self.pow_unc(PrimeField::modulus().val.sub(BigUint56{ limbs: [2, 0, 0, 0, 0] }));
        assert(self.mul(inv).eq(PrimeField::one()));

        inv
    }

    // Checks if the field element is zero.
    fn is_zero(self: Self) -> bool {
        self.val.is_zero()
    }

    // Checks if the field element is one.
    fn is_one(self: Self) -> bool {
        self.eq(PrimeField::one())
    }

    // Checks if self == other.
    fn eq(self: Self, other: Self) -> bool {
        self.val.eq(other.val)
    }

    // Print as bytes
    fn println(self: Self) {
        let bytes = self.to_bytes();
        println(bytes);
    }
}

#[test]
fn test_to_bytes1() {
    let a = PrimeField::zero();
    assert(a.to_bytes() == [0 as u8; MAX_BYTES]);
}

#[test]
fn test_to_bytes2() {
    let a = PrimeField::one();

    let mut bytes = [0 as u8; MAX_BYTES];
    bytes[0] = 1;
    assert(a.to_bytes() == bytes);
}

#[test]
fn test_sub1() {
    let a = PrimeField::from_limbs([5, 0, 0, 0, 0]);
    let b = PrimeField::from_limbs([3, 0, 0, 0, 0]);

    let c = a.sub(b);
    assert(c.eq(PrimeField::from_limbs([2, 0, 0, 0, 0])));
}

#[test]
fn test_sub2() {
    let a = PrimeField::one();
    let b = PrimeField::one().double();

    let c = a.sub(b);
    assert(c.eq(PrimeField::neg(PrimeField::one())));
}

#[test]
fn test_sub3() {
    let a = PrimeField::one();
    let b = PrimeField::one();

    let c = a.sub(b);
    assert(c.eq(PrimeField::zero()));
}

#[test]
fn test_sub4() {
    let a = PrimeField::zero();
    let b = PrimeField::zero();

    let c = a.sub(b);
    assert(c.eq(PrimeField::zero()));
}

#[test]
fn test_add1() {
    let a = PrimeField::from_limbs([5, 0, 0, 0, 0]);
    let b = PrimeField::from_limbs([3, 0, 0, 0, 0]);

    let c = a.add(b);
    assert(c.eq(PrimeField::from_limbs([8, 0, 0, 0, 0])));
}

#[test]
fn test_add2() {
    let a = PrimeField::neg(PrimeField::one());
    let b = PrimeField::one();

    let c = a.add(b);
    assert(c.eq(PrimeField::zero()));
}

#[test]
fn test_add3() {
    let a = PrimeField::neg(PrimeField::one());
    let b = PrimeField::one().double();

    let c = a.add(b);
    assert(c.eq(PrimeField::one()));
}

#[test]
fn test_add4() {
    let a = PrimeField::neg(PrimeField::one());
    let b = PrimeField::neg(PrimeField::one());

    let c = a.add(b);
    assert(c.eq(PrimeField::neg(PrimeField::one().double())));
}

#[test]
fn test_double() {
    let a = PrimeField::from_limbs([3, 0, 0, 0, 0]);
    let c = a.double();
    assert(c.eq(PrimeField::from_limbs([6, 0, 0, 0, 0])));
}

#[test]
fn test_mul1() {
    let a = PrimeField::from_bytes([2]);
    let b = PrimeField::from_bytes([3]);

    let c = a.mul(b);

    assert(c.eq(PrimeField::from_bytes([6])));
}

#[test]
fn test_mul2() {
    // p - 1
    let a = PrimeField::neg(PrimeField::one());
    let b = PrimeField::from_bytes([2]);

    // 2*p - 2
    let c = a.mul(b);
    assert(c.eq(PrimeField::neg(PrimeField::from_bytes([2]))));
}

#[test]
fn test_pow1() {
    let a = PrimeField::zero();
    let b = BigUint56::from_bytes([8]);

    let c = a.pow(b);
    assert(c.eq(PrimeField::zero()));
}

#[test]
fn test_pow2() {
    let a = PrimeField::one();
    let b = BigUint56::from_bytes([8]);

    let c = a.pow(b);
    assert(c.eq(PrimeField::one()));
}

#[test]
fn test_pow3() {
    let a = PrimeField::from_bytes([7]);
    let b = BigUint56::from_bytes([0]);

    let c = a.pow(b);
    assert(c.eq(PrimeField::one()));
}

#[test]
fn test_pow4() {
    let a = PrimeField::from_bytes([7]);
    let b = BigUint56::from_bytes([1]);

    let c = a.pow(b);
    assert(c.eq(a));
}

#[test]
fn test_pow5() {
    let a = PrimeField::from_bytes([7]);
    let b = BigUint56::from_bytes([2]);

    let c = a.pow(b);
    assert(c.eq(PrimeField::from_bytes([49])));
}

#[test]
fn test_invert1() {
    let a = PrimeField::from_bytes([7]);
    let b = a.invert();

    let c = a.mul(b);
    assert(c.eq(PrimeField::one()));
}
