use dep::std::println;
use crate::{BigUint56, NUM_LIMBS, BITS_PER_LIMB, MAX_BITS, MAX_BYTES, utils};

// Field element
struct PrimeField {
    val: BigUint56
}

// INV = -p^{-1} mod 2^{BITS_PER_LIMB}
//     = -p^{-1} mod 2^56
global INV: u56 = 0xb51da312547e1b;

impl PrimeField {
    fn new(val: BigUint56) -> Self {
        Self { val }
    }

    fn from_limbs(limbs: [u56; NUM_LIMBS]) -> Self {
        Self { val: BigUint56{ limbs } }
    }

    fn from_bytes(bytes: [u8]) -> Self {
        let tmp = Self { val: BigUint56::from_bytes(bytes) };

        // Check that tmp < p
        let modulus = PrimeField::modulus();
        assert(tmp.val.lt(modulus.val));

        // Convert to Montgomery form by computing
        // (a.R^0 * R^2) / R = a.R
        tmp.mul(PrimeField::R2())
    }

    // Converts a field element into a byte representation in
    // little-endian byte order.
    fn to_bytes(self: Self) -> [u8; MAX_BYTES] {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = PrimeField::montgomery_reduce([self.val.limbs[0], self.val.limbs[1], self.val.limbs[2], self.val.limbs[3], self.val.limbs[4], 0, 0, 0, 0, 0]);
        tmp.val.to_bytes()
    }

    // Converts a field element into a bit representation
    fn to_bits(self: Self) -> [u1; MAX_BITS] {
        // Turn into canonical form by computing
        // (a.R) / R = a
        let tmp = PrimeField::montgomery_reduce([self.val.limbs[0], self.val.limbs[1], self.val.limbs[2], self.val.limbs[3], self.val.limbs[4], 0, 0, 0, 0, 0]);
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

    // p
    fn modulus() -> Self {
        let val = BigUint56::from_bytes([
            0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 
            0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10
        ]);
        Self { val }
    }

    // R = 2^{BITS_PER_LIMB*NUM_LIMBS} mod p
    //   = 2^280 mod p
    fn R() -> Self {
        let val = BigUint56::from_bytes([
            0xed, 0xd3, 0xf5, 0x8c, 0xdb, 0x05, 0x43, 0xb2, 
            0xa4, 0x76, 0x76, 0x3d, 0x11, 0x80, 0xaf, 0x2a, 
            0x62, 0x10, 0xb2, 0xfe, 0xff, 0xff, 0xff, 0xff, 
            0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x0f
        ]);
        Self { val }
    }

    // R^2 mod p
    fn R2() -> Self {
        let val = BigUint56::from_bytes([
            0xab, 0x05, 0x83, 0x3f, 0x72, 0x5e, 0x8b, 0xe2, 
            0x52, 0x24, 0xf3, 0x5e, 0x1d, 0xef, 0x10, 0x3f, 
            0xa3, 0x97, 0xaa, 0x63, 0x5c, 0xcb, 0x65, 0xbe, 
            0xf5, 0x17, 0xd2, 0x73, 0xec, 0xce, 0x3d, 0x0a
        ]);
        Self { val }
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
        let sum = self.val.add(rhs.val);

        let modulus = PrimeField::modulus().val;
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
        let modulus = PrimeField::modulus().val;
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
        let mut res = [0 as u56; 2*NUM_LIMBS];

        for i in 0..NUM_LIMBS {
            let mut carry = 0;
            for j in 0..NUM_LIMBS {
                let (prod, c) = utils::mac(res[i + j], self.val.limbs[i], other.val.limbs[j], carry);
                res[i + j] = prod;
                carry = c;
            };

            res[i + NUM_LIMBS] = carry;
        };

        PrimeField::montgomery_reduce(res)
    }

    // TODO: Copy instead of mutable array?
    fn montgomery_reduce(mut r: [u56; 2*NUM_LIMBS]) -> Self {
        let modulus = PrimeField::modulus().val;

        let mut carry2 = 0;
        for i in 0..NUM_LIMBS {
            let k = r[i] * INV;
            let mut carry = 0;
            for j in 0..NUM_LIMBS {
                let (prod, c) = utils::mac(r[i + j], k, modulus.limbs[j], carry);
                r[i + j] = prod;
                carry = c;
            }

            let (sum, c) = utils::adc(r[i + NUM_LIMBS], carry2, carry);
            r[i + NUM_LIMBS] = sum;
            carry2 = c;
        }

        let val = BigUint56{ limbs: [r[5], r[6], r[7], r[8], r[9]] };
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

    // Computes the multiplicative inverse of this element,
    // failing if the element is zero.
    fn invert(self: Self) -> Self {
        assert(!self.is_zero());
        // Exponentiate by p - 2
        self.pow(PrimeField::modulus().val.sub(BigUint56{ limbs: [2, 0, 0, 0, 0] }))
    }

    // Print as bytes
    fn println(self: Self) {
        let bytes = self.to_bytes();
        println(bytes);
    }
}