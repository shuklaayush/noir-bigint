use dep::std;
mod u32_utils;
mod arithmetic;
mod division;

global NUM_LIMBS : Field = 8;
global LIMB_BITS : Field = 32;
global LIMB_BYTES : Field = 4;

global DOUBLE_LIMBS : Field = 16;

// This defines a BigInt, a smart wrapper around a sequence of u32 limbs, least-significant limb first
struct BigInt {
    limbs : [u32; NUM_LIMBS],
}

// TODO: impl
struct BigInt2 {
    limbs : [u32; DOUBLE_LIMBS],
}

// TODO: This is a temporary solution that we are using because a struct inside of a tuple doesn't work 
// https://github.com/noir-lang/noir/issues/492
struct LimbsWithOverflow {
    limbs : [u32; NUM_LIMBS],
    overflow: u32,
}

impl BigInt {
    /// Creation

    // Creates and initializes a BigInt.
    fn new(limbs : [u32; NUM_LIMBS]) -> Self {
        Self {
            limbs: limbs
        }
    }

    // Returns the additive identity element
    fn zero() -> Self {
        BigInt::new([0 as u32; NUM_LIMBS])
    }

    // Returns the multiplicative identity element
    fn one() -> Self {
        let mut one = [0 as u32; NUM_LIMBS];
        one[0] = 1;
        BigInt::new(one)
    }
    
    // Returns the big integer representation of a given little endian byte array
    fn from_bytes_le(bytes : [u8]) -> Self {
        // The maximum number of bytes that can fit in this bigint
        let MAX_BYTES : comptime Field = NUM_LIMBS * LIMB_BYTES;
        let SHIFTS : [comptime u32; 4] = [
            u32_utils::U32_POW_2_0,
            u32_utils::U32_POW_2_8,
            u32_utils::U32_POW_2_16,
            u32_utils::U32_POW_2_24,
        ];

        let bytes_len = std::array::len(bytes) as u32;
        
        // TODO: Should we allow this?
        constrain bytes_len <= MAX_BYTES as u32;

        let mut limbs = [0 as u32; NUM_LIMBS];
        let mut limb : u32 = 0;
        for i in 0..MAX_BYTES {
            let limb_index = ((i as u8) / 4) as Field;
            // i modulo 4
            let byte_significance = i - (limb_index * 4);

            if i as u32 < bytes_len {
                let mut byte : u32 = bytes[i] as u32;
                byte = byte * SHIFTS[byte_significance];
                limb = limb | byte;
            }
            if byte_significance == 3 {
                limbs[limb_index] = limb;
                limb = 0;
            }
        };
        // constrain limbs[0] == 1;
        BigInt::new(limbs)
    }
    
    /// Math

    // Returns last non-zero limb, its index, and the limb before it as tuple (msl_index, msl_minus_one, msl).
    // Fails if most_significant_limb index < 1.
    fn two_most_significant_limbs(self : Self) -> (u32, u32, u32) {
        let mut msl_index = 0 as u32;
        let mut msl = 0 as u32;
        let mut msl_minus_one = 0 as u32;
        for i in 0..NUM_LIMBS {
            let j = NUM_LIMBS - i - 1;
            if (self.limbs[j] > 0) & (msl == 0) {
                msl_index = j as u32;
                msl = self.limbs[j];
                msl_minus_one = self.limbs[j - 1];
            }
        };
        constrain msl_index >= 1;
        (msl_index, msl_minus_one, msl)
    }

    // Returns last non-zero limb, its index, and the 2 limbs before it as tuple (msl_index, msl_minus_two, msl_minus_one, msl).
    // Fails if most_significant_limb index < 2.
    fn three_most_significant_limbs(self : Self) -> (u32, u32, u32, u32) {
        let mut msl_index = 0 as u32;
        let mut msl = 0 as u32;
        let mut msl_minus_one = 0 as u32;
        let mut msl_minus_two = 0 as u32;
        for i in 0..NUM_LIMBS {
            let j = NUM_LIMBS - i - 1;
            if (self.limbs[j] > 0) & (msl == 0) {
                msl_index = j as u32;
                msl = self.limbs[j];
                msl_minus_one = self.limbs[j - 1];
                msl_minus_two = self.limbs[j - 2];
            }
        };
        constrain msl_index >= 2;
        (msl_index, msl_minus_two, msl_minus_one, msl)
    }
    
    // Returns self ^ exponent.
    // fn pow(self : Self, exponent : u32) -> Self {
    //     if self.is_one() | exponent == 0 {
    //         BigInt::one();
    //     } else {
    //         if self.is_zero() {
    //             BigInt::zero();
    //         } else {
    //             
    //         }
    //     }
    //     
    // }
    
    // Returns (self ^ exponent) % modulus.
    // fn pow_mod(self : Self, exponent : u32, modulus : Self)
    
    fn add(self : Self, other : BigInt) -> LimbsWithOverflow {
        let mut limbs : [u32; NUM_LIMBS] = [0 as u32; NUM_LIMBS];
        let mut carry : u32 = 0;
        for i in 0..NUM_LIMBS {
            let (limb_sum, new_carry) = arithmetic::add_limbs_with_carry(self.limbs[i], other.limbs[i], carry);
            limbs[i] = limb_sum;
            carry = new_carry;
        };
        LimbsWithOverflow {
            limbs: limbs,
            overflow: carry,
        }
    }

    fn mul(self : Self, other : BigInt) -> BigInt2 {
        // Double limbs won't overflow because the product of two N-limb arrays is never larger than 2N-limbs
        // ((b^n) - 1) * ((b^n) - 1) = b^(2n) - 2(b^n) - 1 < b^(2n)
        let mut limbs  = [0 as u32; DOUBLE_LIMBS];

        for i in 0..NUM_LIMBS {
            let mut carry : u32 = 0;
            for j in 0..NUM_LIMBS {
                let k = i + j;
                let (limb_product, new_carry) = arithmetic::mul_limbs_with_carry(limbs[k], self.limbs[i], other.limbs[j], carry);
                limbs[k] = limb_product;
                carry = new_carry;
            };
            limbs[i + NUM_LIMBS] = carry;
        };

        BigInt2 {
            limbs: limbs,
        }
    }

    // Returns self + other % modulus.
    // fn add_mod(self : Self, other : Self, modulus : Self)
    
    // Returns self * other % modulus.
    // fn mul_mod(self : Self, other : Self, modulus : Self)
    
    // Returns self - other.
    fn sub(self : Self, other : Self) -> LimbsWithOverflow {
        let mut limbs : [u32; NUM_LIMBS] = [0 as u32; NUM_LIMBS];
        let mut borrow : u32 = 0;
        for i in 0..NUM_LIMBS {
            let (limb_diff, new_borrow) = arithmetic::sub_limbs_with_borrow(self.limbs[i], other.limbs[i], borrow);
            limbs[i] = limb_diff;
            borrow = new_borrow;
        };
        
        // ToDo: This is a work around because structs in tuples don't work
        LimbsWithOverflow {
            limbs: limbs,
            overflow: borrow,
        }
    }

    // Returns self - (multiplicand * other).
    fn sub_mul(self : Self, multiplicand : u32, other : BigInt) -> LimbsWithOverflow {
        let mut limbs : [u32; NUM_LIMBS] = [0 as u32; NUM_LIMBS];
        let mut borrow : u32 = 0;
        for i in 0..NUM_LIMBS {
            let (limb_diff, new_borrow) = arithmetic::sub_mul_limbs_with_borrow(self.limbs[i], multiplicand, other.limbs[i], borrow);
            limbs[i] = limb_diff;
            borrow = new_borrow;
        };
        
        // ToDo: This is a work around because structs in tuples don't work
        LimbsWithOverflow {
            limbs: limbs,
            overflow: borrow,
        }
    }

    // Returns true iff this number is even.
    fn is_even(self : Self) -> bool {
        self.limbs[0] % 2 == 0
    }

    // Returns true iff this number is odd.
    fn is_odd(self : Self) -> bool {
        self.limbs[0] % 2 == 1
    }

    // Returns true iff all limbs are zero.
    fn is_zero(self : Self) -> bool {
        let mut result : bool = self.limbs[0] == 0;
        for i in 1..NUM_LIMBS {
            if result == true {
                result = self.limbs[i] == 0;
            }
        };
        result
    }

    // Returns true iff this number is one.
    fn is_one(self : Self) -> bool {
        let mut result : bool = self.limbs[0] == 1;
        for i in 1..NUM_LIMBS {
            if result == true {
                result = self.limbs[i] == 0;
            }
        };
        result
    }
}

// /// Excerpted from https://docs.rs/num-bigint/latest/src/num_bigint/biguint/division.rs.html#210
// /// An implementation of the base division algorithm.
// /// Knuth, TAOCP vol 2 section 4.3.1, algorithm D, with an improvement from exercises 19-21.
fn div_rem_core(mut a: BigInt, b: BigInt) -> BigInt {
    // TODO: debug_assert!(a.data.len() >= b.len() && b.len() > 1);
    // TODO: debug_assert!(b.last().unwrap().leading_zeros() == 0);

    // The algorithm works by incrementally calculating "guesses", q0, for the next digit of the
    // quotient. Once we have any number q0 such that (q0 << j) * b <= a, we can set
    //
    //     q += q0 << j
    //     a -= (q0 << j) * b
    //
    // and then iterate until a < b. Then, (q, a) will be our desired quotient and remainder.
    //
    // q0, our guess, is calculated by dividing the last three digits of a by the last two digits of
    // b - this will give us a guess that is close to the actual quotient, but is possibly greater.
    // It can only be greater by 1 and only in rare cases, with probability at most
    // 2^-(big_digit::BITS-1) for random a, see TAOCP 4.3.1 exercise 21.
    //
    // If the quotient turns out to be too large, we adjust it by 1:
    // q -= 1 << j
    // a += b << j

    // a0 stores an additional extra most significant digit of the dividend, not stored in a.
    let mut a0 = 0 as u32;
    let (mut a_msl_index, mut a2, mut a1) = a.two_most_significant_limbs();

    // [b1, b0] are the two most significant digits of the divisor. They never change.
    let (b_msl_index, b1, b0) = b.two_most_significant_limbs();

    let q_len = a_msl_index - b_msl_index + 1;
    let mut q_limbs = [0 as u32; NUM_LIMBS];
    
    // TODO: REMOVE
    constrain q_limbs[0] == 0;

    for i in 0..NUM_LIMBS {
        let j = NUM_LIMBS - i;
        if j as u32 < q_len {
            // TODO: debug_assert!(a.data.len() == b.len() + j);
            // The first q_estimate is [a2,a1,a0] / [b1,b0]. It will never be too small, it may be too large
            // by at most 1.
            let mut q_estimate = 0 as u32;
            let mut r = 0 as u64;
            if a0 < b0 {
                let result = division::div_wide(a0, a1, a2, b0, b1);
                q_estimate = result.0;
                r = result.1;
            } else {
                // TODO: debug_assert!(a0 == b0);
                // Avoid overflowing q_estimate
                // [a1,a0] = b0 * (1<<BITS - 1) + (a0 + a1)
                // (big_digit::MAX, a0 as DoubleBigDigit + a1 as DoubleBigDigit)
            };
            
            // q_estimate is now either the correct quotient limb, 1 too large.
            // Subtract (q_estimate << j) * b from a. This may overflow, in which case we will have to correct.

            // let mut borrow = sub_mul_digit_same_len(&mut a.data[j..], b, q0);
            let mut sub_mul_result = a.sub_mul(q_estimate, b);
            a = BigInt::new(sub_mul_result.limbs);
            let mut borrow = sub_mul_result.overflow;
            if borrow > 0 {
                // q_estimate is too large. We need to add back one multiple of b.
                q_estimate = q_estimate - 1;
                let add_result = a.add(b);
                a = BigInt::new(add_result.limbs);
                borrow = borrow - add_result.overflow;
            }
            // The top digit of a, stored in a0, has now been zeroed.
            // TODO: debug_assert!(borrow == a0);

            q_limbs[j] = q_estimate;

            // Don't do this on the last iteration when the quotient is fully formed
            if j != 0 {
                let (a_msl_index_update, a2_update, a1_update, a0_update) = a.three_most_significant_limbs();
                a_msl_index = a_msl_index_update;
                a0 = a0_update;
                a1 = a1_update;
                a2 = a2_update;
            }
        }
    };
    // (BigInt::new(q_limbs), a)
    BigInt::new(q_limbs)
}


// Tests
fn run_tests() {
    arithmetic::run_tests();
    division::run_tests();
    test_from_bytes_be();
    test_is_one_zero();
    test_add();
    test_mul();
    test_sub();
    test_sub_mul();
    test_msl();
    // test_div_rem_core();
}

/// from_bytes_be
fn test_from_bytes_be_case1() {
    // TODO: this line causes a weird bug that I think is related to MAX_BYTES existing in a diff function
    // let MAX_BYTES : comptime Field = NUM_LIMBS * LIMB_BYTES;
    let bytes = [1 as u8, 0, 1];
    let bint = BigInt::from_bytes_le(bytes);
    constrain bint.limbs[0] == 1 + 65536;
    for i in 1..NUM_LIMBS {
        constrain bint.limbs[i] == 0;
    };
}

fn test_from_bytes_be_case2() {
    let bytes = [
        0 as u8, 0, 0, 0,
        0, 0, 0, 7,
    ];
    let bint = BigInt::from_bytes_le(bytes);
    constrain bint.limbs[0] == 0;
    constrain bint.limbs[1] == 117440512;
    for i in 2..NUM_LIMBS {
        constrain bint.limbs[i] == 0;
    };
}

fn test_from_bytes_be() {
    test_from_bytes_be_case1();
    test_from_bytes_be_case2();
}


// is_zero, is_one
fn test_is_zero_case1() {
    let a = BigInt::new([0 as u32; NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let zero = BigInt::zero();
    constrain a.is_zero() == true;
    constrain b.is_zero() == false;
    constrain zero.is_zero() == true;
}

fn test_is_one_case1() {
    let a = BigInt::new([0 as u32; NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let one = BigInt::one();
    constrain a.is_one() == false;
    constrain b.is_one() == true;
    constrain one.is_one() == true;
}

fn test_is_one_zero() {
    test_is_zero_case1();
    test_is_one_case1();
}


// add
fn test_add_case1() {
    let a = BigInt::new([1 as u32; NUM_LIMBS]);
    let b = BigInt::new([2 as u32; NUM_LIMBS]);
    let expected_sum_limbs = [3 as u32; NUM_LIMBS];
    let expected_overflow = 0;
    let result = a.add(b);
    constrain result.limbs == expected_sum_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_add_case2() {
    let a = BigInt::new([u32_utils::U32_MAX as u32, u32_utils::U32_MAX as u32, u32_utils::U32_MAX as u32, 0, 0, 0, 0, 0]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_sum_limbs = [0, 0, 0, 1, 0, 0, 0, 0];
    let expected_overflow = 0;
    let result = a.add(b);
    constrain result.limbs == expected_sum_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_add_case3() {
    let a = BigInt::new([u32_utils::U32_MAX as u32; NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_sum_limbs = [0, 0, 0, 0, 0, 0, 0, 0];
    let expected_overflow = 1;
    let result = a.add(b);
    constrain result.limbs == expected_sum_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_add() {
    test_add_case1();
    test_add_case2();
    test_add_case3();
}


// sub
fn test_sub_case1() {
    let a = BigInt::new([3 as u32; NUM_LIMBS]);
    let b = BigInt::new([1 as u32; NUM_LIMBS]);
    let expected_diff_limbs = [2 as u32; NUM_LIMBS];
    let expected_overflow = 0;
    let result = a.sub(b);
    constrain result.limbs == expected_diff_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_sub_case2() {
    let a = BigInt::new([4 as u32, 2, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_diff_limbs : [u32; 8] = [u32_utils::U32_MAX as u32, 1, 0, 0, 0, 0, 0, 0];
    let expected_overflow = 0;
    let result = a.sub(b);
    constrain result.limbs == expected_diff_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_sub_case3() {
    let a = BigInt::new([4 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_diff_limbs : [u32; 8] = [u32_utils::U32_MAX as u32; 8];
    let expected_overflow = 1;
    let result = a.sub(b);
    constrain result.limbs == expected_diff_limbs;
    constrain result.overflow == expected_overflow;
}

fn test_sub() {
    test_sub_case1();
    test_sub_case2();
    test_sub_case3();
}

// mul
fn test_mul_case1() {
    let a = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs = [25 as u32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let product = a.mul(b);
    constrain product.limbs == expected_product_limbs;
}

fn test_mul_case2() {
    let a = BigInt::new([u32_utils::U32_MAX; NUM_LIMBS]);
    let b = BigInt::new([u32_utils::U32_MAX; NUM_LIMBS]);
    let expected_product_limbs = [1 as u32, 0, 0, 0, 0, 0, 0, 0, 4294967294, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295];
    let product = a.mul(b);
    constrain product.limbs == expected_product_limbs;
}

fn test_mul() {
    test_mul_case1();
    test_mul_case2();
}


// sub_mul
fn test_sub_mul_case1() {
    let a = BigInt::new([u32_utils::U32_MAX, u32_utils::U32_MAX, u32_utils::U32_MAX, 0, 0, 0, 0, 0]);
    let b = u32_utils::U32_MAX;
    let c = BigInt::new([u32_utils::U32_MAX, u32_utils::U32_MAX, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [u32_utils::U32_MAX - 1, 0, 1, 0, 0, 0, 0, 0];
    let product = a.sub_mul(b, c);
    constrain product.limbs == expected_product_limbs;
}

fn test_sub_mul() {
    test_sub_mul_case1();
}


// msl
fn test_msl_case1() {
    let a = BigInt::new([u32_utils::U32_MAX, u32_utils::U32_MAX, u32_utils::U32_MAX, 0, 0, 0, 0, 0]);
    let expected_msl_index = 2;
    let expected_msl : u32 = a.limbs[2];
    let expected_msl_minus_one = a.limbs[1];
    let (msl_index, msl_minus_one , msl) = a.two_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
}

fn test_msl_case2() {
    let a = BigInt::new([u32_utils::U32_MAX, u32_utils::U32_MAX, u32_utils::U32_MAX, 0, 0, 0, 0, 1]);
    let expected_msl_index = 7;
    let expected_msl : u32 = 1;
    let expected_msl_minus_one = 0;
    let (msl_index, msl_minus_one , msl) = a.two_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
}

fn test_msl_case3() {
    let a = BigInt::new([0, 0, 100, 0, 1, 0, 0, 0]);
    let expected_msl_index = 4;
    let expected_msl : u32 = 1;
    let expected_msl_minus_one = 0;
    let expected_msl_minus_two = 100;
    let (msl_index, msl_minus_two, msl_minus_one , msl) = a.three_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
    constrain expected_msl_minus_two == msl_minus_two;
}

fn test_msl_case4() {
    let a = BigInt::new([1, 2, 3, 0, 0, 0, 0, 0]);
    let expected_msl_index = 2;
    let expected_msl : u32 = 3;
    let expected_msl_minus_one = 2;
    let expected_msl_minus_two = 1;
    let (msl_index, msl_minus_two, msl_minus_one , msl) = a.three_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
    constrain expected_msl_minus_two == msl_minus_two;
}

fn test_msl() {
    test_msl_case1();
    test_msl_case2();
    test_msl_case3();
    test_msl_case4();
}


// div_rem_core
fn test_div_rem_core_case1() {
    let a = BigInt::new([0, 0, 0, 0, 1, 0, 0, 0]);
    let b = BigInt::new([9, 9, 1, 0, 0, 0, 0, 0]);
    // let expected_product_limbs : [u32; 8] = [u32_utils::U32_MAX - 1, 0, 1, 0, 0, 0, 0, 0];
    let q = div_rem_core(a, b);
    constrain q.limbs[0] != 1;
}

fn test_div_rem_core() {
    test_div_rem_core_case1();
}