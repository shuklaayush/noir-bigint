use dep::std::println;

mod utils;
// mod field_montgomery;

global LIMB_BITS = 56;
global LIMBS = 5;

// TODO: Noir doesn't support const generic/global expressions so these are hardcoded
global BYTES_PER_LIMB = 7; // LIMB_BITS / 8
global MAX_BYTES = 35; // LIMBS * BYTES_PER_LIMB

struct BigUint56 {
    limbs: [u56; LIMBS],
}

impl BigUint56 {
    fn new(limbs: [u56; LIMBS]) -> Self {
        Self {
            limbs
        }
    }

    fn zero() -> Self {
        Self {
            limbs: [0 as u56; LIMBS]
        }
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

    fn add(self: Self, other: Self) -> (Self, u56) {
        let mut res = BigUint56::zero();
        let mut carry = 0 as u56;

        for i in 0..LIMBS {
            let (sum, new_carry) = utils::adc(self.limbs[i], other.limbs[i], carry);
            res.limbs[i] = sum;
            carry = new_carry;
        };

        (res, carry)
    }

    fn sub(self: Self, other: Self) -> (Self, u56) {
        let mut res = BigUint56::zero();
        let mut borrow = 0 as u56;

        for i in 0..LIMBS {
            let (diff, new_borrow) = utils::sbb(self.limbs[i], other.limbs[i], borrow);
            res.limbs[i] = diff;
            borrow = new_borrow;
        };
        
        (res, borrow)
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
        let (_diff, borrow) = self.sub(other);
        borrow == 0
    }

    // Returns true iff this number > other.
    fn gt(self: Self, other: Self) -> bool {
        let (diff, borrow) = self.sub(other);
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

    // Computes `self << shift` where `0 <= shift < Limb::BITS`,
    // returning the result and the carry.
    // TODO: Optimize for 0?
    // fn shl_limb(self: Self, n: u56) -> (Self, u56) {
    //     assert(n < LIMB_BITS);

    //     let mut res = BigUint56::zero();

    //     let rshift = LIMB_BITS - n;
    //     let carry = self.limbs[LIMBS - 1] >> rshift;

    //     for i in LIMBS-1..0 {
    //         res.limbs[i] = (self.limbs[i] << n) | (self.limbs[i - 1] >> rshift);
    //     }
    //     res.limbs[0] = self.limbs[0] << n;

    //     (res, carry)
    // }

    // Computes `self << shift`.
    // TODO: Should n be BigUint56?
    // fn shl(self: Self, n: u56) -> Self {
    //     let mut res = BigUint56::zero();

    //     if n < LIMB_BITS * (LIMBS as u56) {
    //         let shift_num = n / LIMB_BITS;
    //         let rem = n % LIMB_BITS;

    //         for i in 0..LIMBS {
    //             if i as u56 >= shift_num {
    //                 res.limbs[i] = self.limbs[i - shift_num as Field];
    //             }
    //         }

    //         let (new_lower, _carry) = res.shl_limb(rem);
    //         res = new_lower;
    //     }

    //     res
    // }

    // fn div(self: Self, other: Self) -> (Self, Self) {
    //     assert(!other.is_zero());

    //     let mb = other.bits_vartime();
    //     let mut bd = Self::BITS - mb;
    //     let mut rem = *self;
    //     let mut quo = Self::ZERO;
    //     let mut c = other.shl_vartime(bd);

    //     while bd > 0 {
    //         if rem >= c {
    //             rem = rem - c;
    //             quo = (quo << 1) | Self::ONE;
    //         } else {
    //             quo = quo << 1;
    //         }
    //         bd -= 1;
    //         c = c >> 1;
    //     }

    //     // Handle the last bit
    //     if rem >= c {
    //         rem = rem - c;
    //         quo = (quo << 1) | Self::ONE;
    //     } else {
    //         quo = quo << 1;
    //     }

    //     (quo, rem)
    // }

    // // Returns self + other % modulus.
    // // fn add_mod(self : Self, other : Self, modulus : Self)
    
    // // Returns self * other % modulus.
    // // fn mul_mod(self : Self, other : Self, modulus : Self)
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

    let (c, _borrow) = a.sub(b);
    assert(c.to_bytes() == [-1 as u8; MAX_BYTES]);
}

#[test]
fn test_add1() {
    let a = BigUint56::from_bytes([1]);
    let b = BigUint56::from_bytes([2]);
    let (sum, carry) = a.add(b);

    assert(sum.eq(BigUint56::from_bytes([3])));
    assert(carry == 0);
}

#[test]
fn test_add2() {
    let a = BigUint56::new([-1 as u56, -1 as u56, -1 as u56, -1 as u56, 0]);
    let b = BigUint56::new([1, 0, 0, 0, 0]);
    let (sum, carry) = a.add(b);

    assert(sum.eq(BigUint56::new([0, 0, 0, 0, 1])));
    assert(carry == 0);
}

#[test]
fn test_add3() {
    let a = BigUint56::new([-1 as u56; LIMBS]);
    let b = BigUint56::one();
    let (sum, carry) = a.add(b);

    assert(sum.is_zero());
    assert(carry == 1);
}

#[test]
fn test_sub1() {
    let a = BigUint56::from_bytes([5]);
    let b = BigUint56::from_bytes([3]);
    let (diff, borrow) = a.sub(b);

    assert(diff.eq(BigUint56::from_bytes([2])));
    assert(borrow == 0);
}

#[test]
fn test_sub2() {
    let a = BigUint56::new([1, 2, 0, 0, 0]);
    let b = BigUint56::new([2, 0, 0, 0, 0]);
    let (diff, borrow) = a.sub(b);

    assert(diff.eq(BigUint56::new([-1 as u56, 1, 0, 0, 0])));
    assert(borrow == 0);
}

#[test]
fn test_sub3() {
    let a = BigUint56::new([1, 0, 0, 0, 0]);
    let b = BigUint56::new([2, 0, 0, 0, 0]);
    let (diff, borrow) = a.sub(b);

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

// #[test]
// fn test_shl() {
//     let a = BigUint56::new([1, 2]);
//     let b = a.shl(126);

//     let l = b.limbs;
//     println(l);
// }

// TODO: The following would be the ideal implementation with a generic limb type `T`, but this doesn't seem possible in Noir yet.
// struct BigUint<T, LIMBS> {
//     limbs : [T; LIMBS],
// }
// 
// impl<T, LIMBS> BigUint<T, LIMBS> {
//     fn new(limbs: [T; LIMBS]) -> Self {
//         Self {
//             limbs
//         }
//     }
// 
//     fn zero(zero: T) -> Self {
//         Self {
//             limbs: [zero; LIMBS]
//         }
//     }
// }