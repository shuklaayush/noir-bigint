use dep::std::println;
use crate::{BigUint56, NUM_LIMBS, BITS_PER_LIMB, MAX_BITS, MAX_BYTES, utils};

// Field element
struct PrimeField {
    val: BigUint56
}

impl PrimeField {
    ///////////////////////////////////////////////////////////////////////////
    // FIELD SPECIFIC CONSTANTS: Secp256k1 Fp
    ///////////////////////////////////////////////////////////////////////////

    // Prime field modulus
    fn modulus() -> Self {
        let val = BigUint56 { limbs: [0xfffffefffffc2f, 0xffffffffffffff, 0xffffffffffffff, 0xffffffffffffff, 0xffffffff] };
        Self { val }
    }

    // R = 2^{BITS_PER_LIMB*NUM_LIMBS} mod p
    //   = 2^280 mod p
    fn R() -> Self {
        let val = BigUint56 { limbs: [0x03d1000000, 0x01, 0, 0, 0] };
        Self { val }
    }

    // R^2 mod p
    fn R2() -> Self {
        let val = BigUint56 { limbs: [0xa1000000000000, 0x07a2000e90, 0x01, 0, 0] };
        Self { val }
    }

    // INV = -p^{-1} mod 2^{BITS_PER_LIMB}
    //     = -p^{-1} mod 2^56
    fn P_INV() -> u56 {
        0x38091dd2253531
    }

    ///////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    // TODO: Emphasize that there's no montgomery mul here.
    fn from_limbs(limbs: [u56; NUM_LIMBS]) -> Self {
        Self { val: BigUint56{ limbs } }
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

    // Computes the multiplicative inverse of this element,
    // failing if the element is zero.
    fn invert(self: Self) -> Self {
        assert(!self.is_zero());
        // Exponentiate by p - 2
        self.pow(PrimeField::modulus().val.sub(BigUint56{ limbs: [2, 0, 0, 0, 0] }))
    }

    // Checks if the field element is zero.
    fn is_zero(self: Self) -> bool {
        self.val.is_zero()
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

// TODO:
// 1. Dedup when traits