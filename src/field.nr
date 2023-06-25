use dep::std::println;

use crate::{BigUint56, LIMBS, LIMB_BITS, MAX_BYTES, utils};

// Field element
struct FieldElement {
    val: BigUint56
}

// INV = -p^{-1} mod 2^{LIMB_BITS}
//     = -p^{-1} mod 2^56
global INV: u56 = 0xd20782e4866389;

impl FieldElement {
    fn new(val: BigUint56) -> Self {
        Self { val }
    }

    fn from_limbs(limbs: [u56; LIMBS]) -> Self {
        Self { val: BigUint56::new(limbs) }
    }

    fn from_bytes(bytes: [u8]) -> Self {
        let tmp = Self { val: BigUint56::from_bytes(bytes) };

        // Check that tmp < p
        let modulus = FieldElement::modulus();
        assert(tmp.val.lt(modulus.val));

        // Convert to Montgomery form by computing
        // (a.R^0 * R^2) / R = a.R
        tmp.mul(FieldElement::R2())
    }

    // Converts a field element into a byte representation in
    // little-endian byte order.
    fn to_bytes(self: Self) -> [u8; MAX_BYTES] {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = FieldElement::montgomery_reduce([self.val.limbs[0], self.val.limbs[1], self.val.limbs[2], self.val.limbs[3], self.val.limbs[4], 0, 0, 0, 0, 0]);
        tmp.val.to_bytes()
    }

    // Returns zero, the additive identity.
    fn zero() -> Self {
        let val: BigUint56 = BigUint56::zero();
        Self { val }
    }

    // Returns one, the multiplicative identity.
    fn one() -> Self {
        FieldElement::R()
    }

    // p
    fn modulus() -> Self {
        // BN254 modulus    
        let val = BigUint56::from_bytes([
            0x47, 0xfd, 0x7c, 0xd8, 0x16, 0x8c, 0x20, 0x3c, 
            0x8d, 0xca, 0x71, 0x68, 0x91, 0x6a, 0x81, 0x97, 
            0x5d, 0x58, 0x81, 0x81, 0xb6, 0x45, 0x50, 0xb8, 
            0x29, 0xa0, 0x31, 0xe1, 0x72, 0x4e, 0x64, 0x30
        ]);
        Self { val }
    }

    // R = 2^{LIMB_BITS*LIMBS} mod p
    //   = 2^280 mod p
    fn R() -> Self {
        let val = BigUint56::from_bytes([
            0x96, 0x0d, 0x0e, 0x8a, 0xa2, 0x56, 0x6a, 0x97,
            0x8f, 0x6d, 0xb5, 0x92, 0x6c, 0x1e, 0xfc, 0x08,
            0xe6, 0x8e, 0x1c, 0x58, 0x10, 0x5c, 0x6e, 0x9f,
            0xe8, 0xc9, 0x59, 0x8c, 0xa8, 0x9f, 0x35, 0x07
        ]);
        Self { val }
    }

    // R^2 mod p
    fn R2() -> Self {
        let val = BigUint56::from_bytes([
            0x46, 0x3c, 0x69, 0x34, 0x8f, 0x88, 0xbb, 0xdd,
            0xc0, 0x2a, 0xbe, 0xb9, 0x4b, 0x1c, 0xb9, 0xe1,
            0xd9, 0xc3, 0xae, 0xa7, 0xc1, 0x80, 0x35, 0xc8,
            0x22, 0xfa, 0xb4, 0x3c, 0xa9, 0x2e, 0x5e, 0x09
        ]);
        Self { val }
    }

    // Negates `self`.
    fn neg(self: Self) -> Self {
        if self.is_zero() {
            self
        } else {
            // Subtract `self` from `MODULUS` to negate
            let modulus = FieldElement::modulus().val;
            Self { val: modulus.sub(self.val) }
        }
    }

    // Adds `rhs` to `self`, returning the result.
    fn add(self: Self, rhs: Self) -> Self {
        let sum = self.val.add(rhs.val);

        let modulus = FieldElement::modulus().val;
        if (sum.lt(modulus)) {
            Self { val: sum }
        } else {
            // TODO: What if sum overflows BigInt? Maybe check carry?
            Self { val: sum.sub(modulus) }
        }
    }

    // Subtracts `rhs` from `self`, returning the result.
    fn sub(self: Self, rhs: Self) -> Self {
        let (diff, borrow) = self.val.sbb(rhs.val);
        // If underflow occurred on the final limb, borrow = 0xfff...fff, otherwise
        // borrow = 0x000...000. Thus, we use it as a mask to conditionally add the modulus.
        let modulus = FieldElement::modulus().val;
        if borrow == 0 {
            Self { val: diff }
        } else {
            Self { val: diff.add(modulus) }
        }
    }

    // Doubles this field element.
    fn double(self: Self) -> Self {
        self.add(self)
    }

    // Returns true iff this number == other.
    fn is_zero(self: Self) -> bool {
        self.val.is_zero()
    }

    // Returns true iff this number == other.
    fn eq(self: Self, other: Self) -> bool {
        self.val.eq(other.val)
    }

    // Multiplies `rhs` by `self`, returning the result.
    // TODO: Reuse BigUint56 mul?
    fn mul(self: Self, other: Self) -> Self {
        let mut res = [0 as u56; 2*LIMBS];

        for i in 0..LIMBS {
            let mut carry = 0;
            for j in 0..LIMBS {
                let (prod, c) = utils::mac(res[i + j], self.val.limbs[i], other.val.limbs[j], carry);
                res[i + j] = prod;
                carry = c;
            };

            res[i + LIMBS] = carry;
        };

        FieldElement::montgomery_reduce(res)
    }

    // TODO: Copy instead of mutable array?
    fn montgomery_reduce(mut r: [u56; 2*LIMBS]) -> Self {
        let modulus = FieldElement::modulus().val;

        let mut carry2 = 0;
        for i in 0..LIMBS {
            let k = r[i] * INV;
            let mut carry = 0;
            for j in 0..LIMBS {
                let (prod, c) = utils::mac(r[i + j], k, modulus.limbs[j], carry);
                r[i + j] = prod;
                carry = c;
            }

            let (sum, c) = utils::adc(r[i + LIMBS], carry2, carry);
            r[i + LIMBS] = sum;
            carry2 = c;
        }

        let val = BigUint56::new([r[5], r[6], r[7], r[8], r[9]]);
        if val.gte(modulus) {
            Self { val: val.sub(modulus) }
        } else {
            Self { val }
        }
    }

    // Squares this element.
    // TODO: See if more efficient squaring is possible.
    fn square(self: Self) -> Self {
        self.mul(self)
    }

    // Exponentiates `self` by `by`.
    fn pow(self: Self, by: BigUint56) -> Self {
        let mut res = FieldElement::one();
        for i in 0..LIMBS {
            for j in 0..LIMB_BITS {
                res = res.square();
                
                if ((by.limbs[LIMBS - i - 1] >> ((LIMB_BITS - j - 1) as u56)) & 1) == 1 {
                    res = res.mul(self);
                }
            }
        }
        res
    }

    // Computes the multiplicative inverse of this element,
    // failing if the element is zero.
    fn invert(self: Self) -> Self {
        assert(!self.is_zero());
        // Exponentiate by p - 2
        self.pow(FieldElement::modulus().val.sub(BigUint56::new([2, 0, 0, 0, 0])))
    }
}

#[test]
fn test_to_bytes1() {
    let a = FieldElement::zero();
    assert(a.to_bytes() == [0 as u8; MAX_BYTES]);
}

#[test]
fn test_to_bytes2() {
    let a = FieldElement::one();

    let mut bytes = [0 as u8; MAX_BYTES];
    bytes[0] = 1;
    assert(a.to_bytes() == bytes);
}

#[test]
fn test_sub1() {
    let a = FieldElement::from_limbs([5, 0, 0, 0, 0]);
    let b = FieldElement::from_limbs([3, 0, 0, 0, 0]);

    let c = a.sub(b);
    assert(c.eq(FieldElement::from_limbs([2, 0, 0, 0, 0])));
}

#[test]
fn test_sub2() {
    let a = FieldElement::one();
    let b = FieldElement::one().double();

    let c = a.sub(b);
    assert(c.eq(FieldElement::neg(FieldElement::one())));
}

#[test]
fn test_add1() {
    let a = FieldElement::from_limbs([5, 0, 0, 0, 0]);
    let b = FieldElement::from_limbs([3, 0, 0, 0, 0]);

    let c = a.add(b);
    assert(c.eq(FieldElement::from_limbs([8, 0, 0, 0, 0])));
}

#[test]
fn test_add2() {
    let a = FieldElement::neg(FieldElement::one());
    let b = FieldElement::one();

    let c = a.add(b);
    assert(c.eq(FieldElement::zero()));
}

#[test]
fn test_add3() {
    let a = FieldElement::neg(FieldElement::one());
    let b = FieldElement::one().double();

    let c = a.add(b);
    assert(c.eq(FieldElement::one()));
}

#[test]
fn test_double() {
    let a = FieldElement::from_limbs([3, 0, 0, 0, 0]);
    let c = a.double();
    assert(c.eq(FieldElement::from_limbs([6, 0, 0, 0, 0])));
}

#[test]
fn test_mul1() {
    let a = FieldElement::from_bytes([2]);
    let b = FieldElement::from_bytes([3]);

    let c = a.mul(b);

    assert(c.eq(FieldElement::from_bytes([6])));
}

#[test]
fn test_mul2() {
    // p - 1
    let a = FieldElement::neg(FieldElement::one());
    let b = FieldElement::from_bytes([2]);

    // 2*p - 2
    let c = a.mul(b);
    assert(c.eq(FieldElement::neg(FieldElement::from_bytes([2]))));
}

#[test]
fn test_pow1() {
    let a = FieldElement::zero();
    let b = BigUint56::from_bytes([8]);

    let c = a.pow(b);
    assert(c.eq(FieldElement::zero()));
}

#[test]
fn test_pow2() {
    let a = FieldElement::one();
    let b = BigUint56::from_bytes([8]);

    let c = a.pow(b);
    assert(c.eq(FieldElement::one()));
}

#[test]
fn test_pow3() {
    let a = FieldElement::from_bytes([7]);
    let b = BigUint56::from_bytes([0]);

    let c = a.pow(b);
    assert(c.eq(FieldElement::one()));
}

#[test]
fn test_pow4() {
    let a = FieldElement::from_bytes([7]);
    let b = BigUint56::from_bytes([1]);

    let c = a.pow(b);
    assert(c.eq(a));
}

#[test]
fn test_pow5() {
    let a = FieldElement::from_bytes([7]);
    let b = BigUint56::from_bytes([2]);

    let c = a.pow(b);
    assert(c.eq(FieldElement::from_bytes([49])));
}

#[test]
fn test_invert1() {
    let a = FieldElement::from_bytes([7]);
    let b = a.invert();

    let c = a.mul(b);
    assert(c.eq(FieldElement::one()));
}

// TODO:
// 1. Remove dependency on BigUint56 and reimplement all functions here.