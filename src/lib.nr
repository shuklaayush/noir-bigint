use dep::std::println;
mod utils;

struct BigUint63<LIMBS> {
    limbs: [u63; LIMBS],
}

impl<LIMBS> BigUint63<LIMBS> {
    fn new(limbs: [u63; LIMBS]) -> Self {
        Self {
            limbs
        }
    }

    fn zero() -> Self {
        Self {
            limbs: [0 as u63; LIMBS]
        }
    }

    fn one() -> Self {
        let mut one = BigUint63::zero();
        one.limbs[0] = 1;
        one
    }

    fn add(self: Self, other: Self) -> (Self, u63) {
        let mut res = BigUint63::zero();
        let mut carry = 0 as u63;

        for i in 0..LIMBS {
            let (sum, new_carry) = utils::adc(self.limbs[i], other.limbs[i], carry);
            res.limbs[i] = sum;
            carry = new_carry;
        };

        (res, carry)
    }
    
    fn sub(self: Self, other: Self) -> (Self, u63) {
        let mut res = BigUint63::zero();
        let mut borrow = 0 as u63;

        for i in 0..LIMBS {
            let (diff, new_borrow) = utils::sbb(self.limbs[i], other.limbs[i], borrow);
            res.limbs[i] = diff;
            borrow = new_borrow;
        };
        
        (res, borrow)
    }

    fn mul(self: Self, other: Self) -> (Self, Self) {
        let mut lo = BigUint63::zero();
        let mut hi = BigUint63::zero();

        for i in 0..LIMBS {
            let mut carry = 0 as u63;

            for j in 0..LIMBS {
                let k = i + j;

                if k >= LIMBS {
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
        (borrow == 0) & !diff.eq(BigUint63::zero())
    }

    // Returns true iff this number <= other.
    fn lte(self: Self, other: Self) -> bool {
        other.gte(self)
    }

    // Returns true iff this number < other.
    fn lt(self: Self, other: Self) -> bool {
        other.gt(self)
    }

    // // Returns self + other % modulus.
    // // fn add_mod(self : Self, other : Self, modulus : Self)
    
    // // Returns self * other % modulus.
    // // fn mul_mod(self : Self, other : Self, modulus : Self)
    
    // fn shift(self : Self, shift : u32, left : bool) -> BigInt {
    //     assert(shift < 8);
    //     let mut limbs = self.limbs;
    //     for i in 0..constants::NUM_LIMBS {
    //         if i as u32 < constants::NUM_LIMBS as u32 - shift {
    //             if left == true {
    //                 if shift == 1 {
    //                     limbs[i] = self.limbs[i + 1];
    //                 }
    //                 if shift == 2 {
    //                     limbs[i] = self.limbs[i + 2];
    //                 }
    //                 if shift == 3 {
    //                     limbs[i] = self.limbs[i + 3];
    //                 }
    //                 if shift == 4 {
    //                     limbs[i] = self.limbs[i + 4];
    //                 }
    //                 if shift == 5 {
    //                     limbs[i] = self.limbs[i + 5];
    //                 }
    //                 if shift == 6 {
    //                     limbs[i] = self.limbs[i + 6];
    //                 }
    //                 if shift == 7 {
    //                     limbs[i] = self.limbs[i + 7];
    //                 }
    //             } else {
    //                 if shift == 1 {
    //                     limbs[i + 1] = self.limbs[i];
    //                 }
    //                 if shift == 2 {
    //                     limbs[i + 2] = self.limbs[i];
    //                 }
    //                 if shift == 3 {
    //                     limbs[i + 3] = self.limbs[i];
    //                 }
    //                 if shift == 4 {
    //                     limbs[i + 4] = self.limbs[i];
    //                 }
    //                 if shift == 5 {
    //                     limbs[i + 5] = self.limbs[i];
    //                 }
    //                 if shift == 6 {
    //                     limbs[i + 6] = self.limbs[i];
    //                 }
    //                 if shift == 7 {
    //                     limbs[i + 7] = self.limbs[i];
    //                 }
    //             }
    //         } else {
    //             if left == true {
    //                 limbs[i] = 0;
    //             } else {
    //                 limbs[constants::NUM_LIMBS - i - 1] = 0;
    //             }
    //         }
    //     }
    //     BigInt::new(limbs)
    // }

    // // Returns self - (multiplicand * other).
    // fn sub_mul(self : Self, limb_shift : u32, multiplicand : u32, other : BigInt) -> (BigInt, u32) {
    //     let shifted = self.shift(limb_shift, true);
    //     let mut limbs : [u32; constants::NUM_LIMBS] = [0 as u32; constants::NUM_LIMBS];
    //     let mut borrow : u32 = 0;
    //     for i in 0..constants::NUM_LIMBS {
    //         let (limb_diff, new_borrow) = utils::sub_mul_limbs_with_borrow(shifted.limbs[i], multiplicand, other.limbs[i], borrow);
    //         limbs[i] = limb_diff;
    //         borrow = new_borrow;
    //     };
    //     let unshifted = BigInt::new(limbs).shift(limb_shift, false);
    //     let mut result = unshifted.limbs;
    //     for i in 0..constants::NUM_LIMBS {
    //         if i as u32 < limb_shift {
    //             result[i] = self.limbs[i];
    //         }
    //     };
        
    //     (BigInt::new(result), borrow)
    // }
}

#[test]
fn test_add1() {
    let a = BigUint63::new([1, 0, 0, 0]);
    let b = BigUint63::new([2, 0, 0, 0]);
    let (sum, carry) = a.add(b);

    assert(sum.eq(BigUint63::new([3, 0, 0, 0])));
    assert(carry == 0);
}

#[test]
fn test_add2() {
    let a = BigUint63::new([-1 as u63, -1 as u63, -1 as u63, 0]);
    let b = BigUint63::new([1, 0, 0, 0]);
    let (sum, carry) = a.add(b);

    assert(sum.eq(BigUint63::new([0, 0, 0, 1])));
    assert(carry == 0);
}

#[test]
fn test_add3() {
    let a = BigUint63::new([-1 as u63; 4]);
    let b = BigUint63::new([1, 0, 0, 0]);
    let (sum, carry) = a.add(b);

    assert(sum.eq(BigUint63::zero()));
    assert(carry == 1);
}

#[test]
fn test_sub1() {
    let a = BigUint63::new([5, 0, 0, 0]);
    let b = BigUint63::new([3, 0, 0, 0]);
    let (diff, borrow) = a.sub(b);

    assert(diff.eq(BigUint63::new([2, 0, 0, 0])));
    assert(borrow == 0);
}

#[test]
fn test_sub2() {
    let a = BigUint63::new([1, 2, 0, 0]);
    let b = BigUint63::new([2, 0, 0, 0]);
    let (diff, borrow) = a.sub(b);

    assert(diff.eq(BigUint63::new([-1 as u63, 1, 0, 0])));
    assert(borrow == 0);
}

#[test]
fn test_sub3() {
    let a = BigUint63::new([1, 0, 0, 0]);
    let b = BigUint63::new([2, 0, 0, 0]);
    let (diff, borrow) = a.sub(b);

    assert(diff.eq(BigUint63::new([-1 as u63; 4])));
    assert(borrow >> 62 == 1);
}

#[test]
fn test_mul1() {
    let a = BigUint63::new([2, 0, 0, 0]);
    let b = BigUint63::new([3, 0, 0, 0]);
    let (lo, hi) = a.mul(b);

    assert(lo.eq(BigUint63::new([6, 0, 0, 0])));
    assert(hi.eq(BigUint63::zero()));
}

#[test]
fn test_mul2() {
    let a = BigUint63::new([-1 as u63; 4]);
    let b = BigUint63::new([-1 as u63; 4]);
    let (lo, hi) = a.mul(b);

    assert(lo.eq(BigUint63::new([1, 0, 0, 0])));
    assert(hi.eq(BigUint63::new([-2 as u63, -1 as u63, -1 as u63, -1 as u63])));
}

#[test]
fn test_cmp1() {
    let x = BigUint63::new([2, 0]);
    let y = BigUint63::new([0, 2]);

    assert(!x.eq(y));

    assert(x.lte(y));
    assert(!x.gte(y));

    assert(x.lt(y));
    assert(!x.gt(y));
}

#[test]
fn test_cmp2() {
    let x = BigUint63::new([0, 2]);
    let y = BigUint63::new([0, 2]);

    assert(x.eq(y));

    assert(x.lte(y));
    assert(x.gte(y));

    assert(!x.lt(y));
    assert(!x.gt(y));
}

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