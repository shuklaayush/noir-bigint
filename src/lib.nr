// use dep::std::println;
mod utils;

global LIMB_BITS: u63 = 63;

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

    fn is_zero(self: Self) -> bool {
        self.eq(BigUint63::zero())
    }

    // Computes `self << shift` where `0 <= shift < Limb::BITS`,
    // returning the result and the carry.
    // TODO: Optimize for 0?
    // fn shl_limb(self: Self, n: u63) -> (Self, u63) {
    //     assert(n < LIMB_BITS);

    //     let mut res = BigUint63::zero();

    //     let rshift = LIMB_BITS - n;
    //     let carry = self.limbs[LIMBS - 1] >> rshift;

    //     for i in LIMBS-1..0 {
    //         res.limbs[i] = (self.limbs[i] << n) | (self.limbs[i - 1] >> rshift);
    //     }
    //     res.limbs[0] = self.limbs[0] << n;

    //     (res, carry)
    // }

    // Computes `self << shift`.
    // TODO: Should n be BigUint63?
    // fn shl(self: Self, n: u63) -> Self {
    //     let mut res = BigUint63::zero();

    //     if n < LIMB_BITS * (LIMBS as u63) {
    //         let shift_num = n / LIMB_BITS;
    //         let rem = n % LIMB_BITS;

    //         for i in 0..LIMBS {
    //             if i as u63 >= shift_num {
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

    //     let mb = rhs.bits_vartime();
    //     let mut bd = Self::BITS - mb;
    //     let mut rem = *self;
    //     let mut quo = Self::ZERO;
    //     let mut c = rhs.shl_vartime(bd);

    //     loop {
    //         let (mut r, borrow) = rem.sbb(&c, Limb::ZERO);
    //         rem = Self::ct_select(&r, &rem, CtChoice::from_mask(borrow.0));
    //         r = quo.bitor(&Self::ONE);
    //         quo = Self::ct_select(&r, &quo, CtChoice::from_mask(borrow.0));
    //         if bd == 0 {
    //             break;
    //         }
    //         bd -= 1;
    //         c = c.shr_vartime(1);
    //         quo = quo.shl_vartime(1);
    //     }

    //     (quo, rem)
    // }

    // // Returns self + other % modulus.
    // // fn add_mod(self : Self, other : Self, modulus : Self)
    
    // // Returns self * other % modulus.
    // // fn mul_mod(self : Self, other : Self, modulus : Self)
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

    assert(sum.is_zero());
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
    assert(hi.is_zero());
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
    let a = BigUint63::new([2, 0]);
    let b = BigUint63::new([0, 2]);

    assert(!a.eq(b));

    assert(a.lte(b));
    assert(!a.gte(b));

    assert(a.lt(b));
    assert(!a.gt(b));
}

#[test]
fn test_cmp2() {
    let a = BigUint63::new([0, 2]);
    let b = BigUint63::new([0, 2]);

    assert(a.eq(b));

    assert(a.lte(b));
    assert(a.gte(b));

    assert(!a.lt(b));
    assert(!a.gt(b));
}

// #[test]
// fn test_shl() {
//     let a = BigUint63::new([1, 2]);
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