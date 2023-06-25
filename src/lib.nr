use dep::std::println;

mod utils;
mod field;

// TODO: Strongly type all globals as either Field or u56
//       BUG: Noir should automatically add `comptime` to all globals
//       Rename to BITS_PER_LIMB? Change to Field?
global LIMB_BITS: comptime u56 = 56;
global LIMBS: comptime Field = 5;

// TODO: Noir doesn't support global expressions so these are hardcoded
global MAX_BITS: Field = 280; // LIMB_BITS * LIMBS
global BYTES_PER_LIMB = 7; // LIMB_BITS / 8
global MAX_BYTES = 35; // LIMBS * BYTES_PER_LIMB

struct BigUint56 {
    limbs: [u56; LIMBS],
}

impl BigUint56 {
    fn new(limbs: [u56; LIMBS]) -> Self {
        Self { limbs }
    }

    fn zero() -> Self {
        Self { limbs: [0 as u56; LIMBS] }
    }

    fn one() -> Self {
        let mut one = BigUint56::zero();
        one.limbs[0] = 1;
        one
    }

    // Returns the big integer representation of a given little endian byte array
    // TODO: Fix number of bytes? What are the trade-offs of having a fixed number of LIMBS vs using [u8]?
    fn from_bytes(bytes: [u8]) -> Self {
        assert(bytes.len() as u56 <= MAX_BYTES as u56);

        let mut res = BigUint56::zero();
        for i in 0..bytes.len() {
            let limb_index = (i as u56) / (BYTES_PER_LIMB as u56);
            let byte_index = (i as u56) % (BYTES_PER_LIMB as u56);

            res.limbs[limb_index as Field] |= (bytes[i] as u56) << (byte_index * 8);
        }

        res
    }

    // TODO: Use builtin `to_le_bytes`?
    fn to_bytes(self: Self) -> [u8; MAX_BYTES] {
        let mut res = [0 as u8; MAX_BYTES];
    
        for i in 0..LIMBS {
            for j in 0..BYTES_PER_LIMB {
                let idx = i * BYTES_PER_LIMB + j;
                let byte = (self.limbs[i] >> (j * 8) as u56) & 0xFF;
                res[idx] = (byte as u8);
            }
        }
    
        res
    }

    // TODO: Use builtin `to_le_bits`?
    fn to_bits(self: Self) -> [u1; MAX_BITS] {
        let mut res = [0 as u1; MAX_BITS];
    
        for i in 0..LIMBS {
            for j in 0..LIMB_BITS {
                let idx = i * (LIMB_BITS as Field) + (j as Field);
                let bit = (self.limbs[i] >> j as u56) & 0x01;
                res[idx] = bit as u1;
            }
        }
    
        res
    }

    fn adc(self: Self, other: Self) -> (Self, u56) {
        let mut res = BigUint56::zero();
        let mut carry = 0 as u56;

        for i in 0..LIMBS {
            let (sum, new_carry) = utils::adc(self.limbs[i], other.limbs[i], carry);
            res.limbs[i] = sum;
            carry = new_carry;
        };

        (res, carry)
    }

    // TODO: Check if carry is 0?
    fn add(self: Self, other: Self) -> Self {
        let (res, _carry) = self.adc(other);
        res
    }

    fn sbb(self: Self, other: Self) -> (Self, u56) {
        let mut res = BigUint56::zero();
        let mut borrow = 0 as u56;

        for i in 0..LIMBS {
            let (diff, new_borrow) = utils::sbb(self.limbs[i], other.limbs[i], borrow);
            res.limbs[i] = diff;
            borrow = new_borrow;
        };
        
        (res, borrow)
    }

    // TODO: Check if borrow is 0?
    fn sub(self: Self, other: Self) -> Self {
        let (res, _borrow) = self.sbb(other);
        res
    }

    fn mul(self: Self, other: Self) -> (Self, Self) {
        let mut lo = BigUint56::zero();
        let mut hi = BigUint56::zero();

        for i in 0..LIMBS {
            let mut carry = 0 as u56;

            for j in 0..LIMBS {
                let k = i + j;

                if k as u56 >= LIMBS as u56 {
                    let (n, c) = utils::mac(hi.limbs[k - LIMBS], self.limbs[i], other.limbs[j], carry);
                    hi.limbs[k - LIMBS] = n;
                    carry = c;
                } else {
                    let (n, c) = utils::mac(lo.limbs[k], self.limbs[i], other.limbs[j], carry);
                    lo.limbs[k] = n;
                    carry = c;
                }
            };

            hi.limbs[i] = carry;
        };

        (lo, hi)
    }

    // Computes `self << shift` where `0 <= shift < Limb::BITS`,
    // returning the result and the carry.
    // TODO: Optimize for 0?
    fn shl_limb(self: Self, n: u56) -> (Self, u56) {
        assert(n < LIMB_BITS);

        let mut res = BigUint56::zero();

        let rshift = LIMB_BITS - n;
        let carry = self.limbs[LIMBS - 1] >> rshift;

        res.limbs[0] = self.limbs[0] << n;
        for i in 1..LIMBS {
            res.limbs[i] = (self.limbs[i] << n) | (self.limbs[i - 1] >> rshift);
        // TODO: Bug, this doesn't work without the semi-colon.
        };

        (res, carry)
    }

    // Computes `self << shift`.
    // TODO: Should n be BigUint56?
    fn shl(self: Self, n: u56) -> Self {
        let mut res = BigUint56::zero();

        if n < MAX_BITS as u56 {
            let shift_num = n / LIMB_BITS;
            let rem = n % LIMB_BITS;

            for i in 0..LIMBS {
                if i as u56 >= shift_num {
                    res.limbs[i] = self.limbs[i - shift_num as Field];
                }
            }

            let (new_lower, _carry) = res.shl_limb(rem);
            res = new_lower;
        }

        res
    }

    // TODO: 
    //      1. Optimize for 0?
    //      2. Combine with shr since there is no carry?
    fn shr_limb(self: Self, n: u56) -> Self {
        assert(n < LIMB_BITS);

        let mut res = BigUint56::zero();
        let lshift = LIMB_BITS - n;

        for i in 0..LIMBS-1 {
            res.limbs[i] = (self.limbs[i] >> n) | (self.limbs[i + 1] << lshift);
        }
        res.limbs[LIMBS - 1] = self.limbs[LIMBS - 1] >> n;

        res
    }

    // TODO: Should n be BigUint56?
    fn shr(self: Self, n: u56) -> Self {
        let mut res = BigUint56::zero();

        if n < MAX_BITS as u56 {
            let shift_num = n / LIMB_BITS;
            let rem = n % LIMB_BITS;

            for i in 0..LIMBS {
                if i as u56 + shift_num < LIMBS as u56 {
                    res.limbs[i] = self.limbs[i + shift_num as Field];
                }
            }

            res = res.shr_limb(rem);
        }

        res
    }

    // TODO: Probably don't need this.
    fn bit(self: Self, index: u56) -> u56 {
        assert(index < MAX_BITS as u56);

        let limb_index = index / LIMB_BITS;
        let bit_index = index % LIMB_BITS;

        let limb = self.limbs[limb_index as Field];
        (limb >> bit_index) & 1
    }

    // TODO: Use built-in to_le_bits and see if it's more efficient.
    //       Use `to_bits` above
    fn bits(self: Self) -> u56 {
        let mut res = 0;
        let mut done = false;
        for i in 1..MAX_BITS {
            if !done {
                let index = (MAX_BITS - i) as u56;
                if self.bit(index) != 0 {
                    res = index + 1;
                    done = true;
                }
            }
        }

        res
    }

    // TODO: Use a more efficient algorithm. This is simple binary long division.
    fn div(self: Self, other: Self) -> (Self, Self) {
        assert(!other.is_zero());

        if self.lt(other) {
            (BigUint56::zero(), self)
        } else {
            let mut rem = self;
            let mut quo = BigUint56::zero();

            let bit_diff = self.bits() - other.bits();
            let mut c = other.shl(bit_diff);

            for i in 0..MAX_BITS+1 {
                if i as u56 <= bit_diff {
                    if rem.gte(c) {
                        rem = rem.sub(c);
                        quo = quo.shl(1).add(BigUint56::one());
                    } else {
                        quo = quo.shl(1);
                    }
                    c = c.shr(1);
                }
            };

            (quo, rem)
        }
    }

    // Returns true iff this number == other.
    fn eq(self: Self, other: Self) -> bool {
        let mut is_eq = true;
        let mut done = false;
        for i in 0..LIMBS {
            // TODO: Compare constraints with
            // is_eq = is_eq & (self.limbs[i] == other.limbs[i]);
            if (!done) {
                if self.limbs[i] != other.limbs[i] {
                    is_eq = false;
                    done = true;
                }
            }
        }
        is_eq
    }

    // Returns true iff this number >= other.
    fn gte(self: Self, other: Self) -> bool {
        let (_diff, borrow) = self.sbb(other);
        borrow == 0
    }

    // Returns true iff this number > other.
    fn gt(self: Self, other: Self) -> bool {
        let (diff, borrow) = self.sbb(other);
        (borrow == 0) & !diff.eq(BigUint56::zero())
    }

    // Returns true iff this number <= other.
    fn lte(self: Self, other: Self) -> bool {
        other.gte(self)
    }

    // Returns true iff this number < other.
    fn lt(self: Self, other: Self) -> bool {
        other.gt(self)
    }

    fn is_zero(self: Self) -> bool {
        self.eq(BigUint56::zero())
    }

    // Returns self + other % modulus.
    // Assumes `self + other` as unbounded integer is `< 2*modulus`.
    fn add_mod(self: Self, other: Self, modulus: Self) -> Self {
        let (sum1, carry) = self.adc(other);

        // Attempt to subtract the modulus, to ensure the result is in the field.
        let (sum2, borrow1) = sum1.sbb(modulus);
        let (_diff, borrow2) = utils::sbb(carry, 0 as u56, borrow1);

        if borrow2 == 0 {
            sum2
        } else {
            sum2.add(modulus)
        }
    }
    
    // Returns self * other % modulus.
    // fn mul_mod(self : Self, other : Self, modulus : Self)
}

#[test]
fn test_from_bytes1() {
    let bytes = [2 as u8];
    let a = BigUint56::from_bytes(bytes);
    assert(a.eq(BigUint56::new([2, 0, 0, 0, 0])));
}

#[test]
fn test_from_bytes2() {
    let bytes = [255 as u8; 7];
    let a = BigUint56::from_bytes(bytes);
    assert(a.eq(BigUint56::new([-1 as u56, 0, 0, 0, 0])));
}

#[test]
fn test_from_bytes3() {
    let bytes = [255 as u8; 8];
    let a = BigUint56::from_bytes(bytes);
    assert(a.eq(BigUint56::new([-1 as u56, 255, 0, 0, 0])));
}

#[test]
fn test_to_bytes1() {
    let a = BigUint56::zero();
    let b = BigUint56::one();

    let c = a.sub(b);
    assert(c.to_bytes() == [-1 as u8; MAX_BYTES]);
}

#[test]
fn test_to_bits1() {
    let a = BigUint56::zero();
    let b = BigUint56::one();

    let c = a.sub(b);
    assert(c.to_bits() == [1 as u1; MAX_BITS]);
}

#[test]
fn test_add1() {
    let a = BigUint56::from_bytes([1]);
    let b = BigUint56::from_bytes([2]);
    let sum = a.add(b);

    assert(sum.eq(BigUint56::from_bytes([3])));
}

#[test]
fn test_add2() {
    let a = BigUint56::new([-1 as u56, -1 as u56, -1 as u56, -1 as u56, 0]);
    let b = BigUint56::new([1, 0, 0, 0, 0]);
    let sum = a.add(b);

    assert(sum.eq(BigUint56::new([0, 0, 0, 0, 1])));
}

#[test]
fn test_adc1() {
    let a = BigUint56::new([-1 as u56; LIMBS]);
    let b = BigUint56::one();
    let (sum, carry) = a.adc(b);

    assert(sum.is_zero());
    assert(carry == 1);
}

#[test]
fn test_sub1() {
    let a = BigUint56::from_bytes([5]);
    let b = BigUint56::from_bytes([3]);
    let diff = a.sub(b);

    assert(diff.eq(BigUint56::from_bytes([2])));
}

#[test]
fn test_sub2() {
    let a = BigUint56::new([1, 2, 0, 0, 0]);
    let b = BigUint56::new([2, 0, 0, 0, 0]);
    let diff = a.sub(b);

    assert(diff.eq(BigUint56::new([-1 as u56, 1, 0, 0, 0])));
}

#[test]
fn test_sbb1() {
    let a = BigUint56::new([1, 0, 0, 0, 0]);
    let b = BigUint56::new([2, 0, 0, 0, 0]);
    let (diff, borrow) = a.sbb(b);

    assert(diff.eq(BigUint56::new([-1 as u56; 5])));
    assert(borrow >> (LIMB_BITS - 1) == 1);
}

#[test]
fn test_mul1() {
    let a = BigUint56::from_bytes([2]);
    let b = BigUint56::from_bytes([3]);
    let (lo, hi) = a.mul(b);

    assert(lo.eq(BigUint56::from_bytes([6])));
    assert(hi.is_zero());
}

#[test]
fn test_mul2() {
    let a = BigUint56::new([-1 as u56; 5]);
    let b = BigUint56::new([-1 as u56; 5]);
    let (lo, hi) = a.mul(b);

    assert(lo.eq(BigUint56::one()));
    assert(hi.eq(BigUint56::new([-2 as u56, -1 as u56, -1 as u56, -1 as u56, -1 as u56])));
}

#[test]
fn test_cmp1() {
    let a = BigUint56::from_bytes([2, 0]);
    let b = BigUint56::from_bytes([0, 2]);

    assert(!a.eq(b));

    assert(a.lte(b));
    assert(!a.gte(b));

    assert(a.lt(b));
    assert(!a.gt(b));
}

#[test]
fn test_cmp2() {
    let a = BigUint56::from_bytes([0, 2]);
    let b = BigUint56::from_bytes([0, 2]);

    assert(a.eq(b));

    assert(a.lte(b));
    assert(a.gte(b));

    assert(!a.lt(b));
    assert(!a.gt(b));
}

#[test]
fn test_shl1() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shl(0);

    assert(a.eq(b));
}

#[test]
fn test_shl2() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shl(MAX_BITS as u56);

    assert(b.is_zero());
}

#[test]
fn test_shl3() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shl(1);

    let bytes = b.to_bytes();

    let mut expected = [0 as u8; MAX_BYTES];
    expected[0] = 2;
    expected[1] = 4;

    assert(bytes == expected);
}

#[test]
fn test_shl4() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shl(8);

    assert(b.eq(BigUint56::from_bytes([0, 1, 2])));
}

#[test]
fn test_shl5() {
    let a = BigUint56::from_bytes([1]);
    let b = a.shl(1);

    assert(b.eq(BigUint56::from_bytes([2])));
}

#[test]
fn test_shr1() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shr(0);

    assert(a.eq(b));
}

#[test]
fn test_shr2() {
    let a = BigUint56::from_bytes([1, 2]);
    let b = a.shr(MAX_BITS as u56);

    assert(b.is_zero());
}

#[test]
fn test_shr3() {
    let a = BigUint56::from_bytes([2, 4]);
    let b = a.shr(1);

    let bytes = b.to_bytes();

    let mut expected = [0 as u8; MAX_BYTES];
    expected[0] = 1;
    expected[1] = 2;

    assert(bytes == expected);
}

#[test]
fn test_shr4() {
    let a = BigUint56::from_bytes([0, 1, 2]);
    let b = a.shr(8);

    assert(b.eq(BigUint56::from_bytes([1, 2])));
}

#[test]
fn test_bits1() {
    let a = BigUint56::from_bytes([0]);
    let b = a.bits();

    assert(b == 0);
}

#[test]
fn test_bits2() {
    let a = BigUint56::from_bytes([1]);
    let b = a.bits();

    println(b);
    // assert(b == 1);
}

#[test]
fn test_bits3() {
    let a = BigUint56::from_bytes([-1 as u8]);
    let b = a.bits();

    assert(b == 8);
}

#[test]
fn test_bits4() {
    let a = BigUint56::from_bytes([1, 5]);
    let b = a.bits();

    assert(b == 11);
}

#[test]
fn test_div1() {
    let a = BigUint56::from_bytes([7]);
    let b = BigUint56::from_bytes([3]);

    let (q, r) = a.div(b);

    assert(q.eq(BigUint56::from_bytes([2])));
    assert(r.eq(BigUint56::from_bytes([1])));
}

#[test]
fn test_div2() {
    let a = BigUint56::from_bytes([7]);
    let b = BigUint56::from_bytes([1]);

    let (q, r) = a.div(b);

    assert(q.eq(BigUint56::from_bytes([7])));
    assert(r.eq(BigUint56::from_bytes([0])));
}

#[test]
fn test_add_mod1() {
    let a = BigUint56::from_bytes([2]);
    let b = BigUint56::from_bytes([7]);
    let c = BigUint56::from_bytes([5]);

    let d = a.add_mod(b, c);
    assert(d.eq(BigUint56::from_bytes([4])));
}

// TODO: 
// 1. The operations as implemented here are inefficient in the context of crypto libraries but it's a good start.
// 2. Remove `carry` from `add`, `sub`, `mul` and `div` and implement it in a separate function.
// 3. Remove unnecessary ::new constructors.
//
// 4. The following would be the ideal implementation with a generic limb type `T`, but this doesn't seem possible in Noir yet.
//  struct BigUint<T, LIMBS> {
//      limbs : [T; LIMBS],
//  }
//
//  impl<T, LIMBS> BigUint<T, LIMBS> {
//      fn new(limbs: [T; LIMBS]) -> Self {
//          Self {
//              limbs
//          }
//      }
//
//      fn zero(zero: T) -> Self {
//          Self {
//              limbs: [zero; LIMBS]
//          }
//      }

// References:
// 1. https://github.com/rust-num/num-bigint
// 2. https://github.com/RustCrypto/crypto-bigint