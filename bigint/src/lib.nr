mod constants;
mod arithmetic;
mod division;

// This defines a BigInt, a smart wrapper around a sequence of u32 limbs, least-significant limb first
struct BigInt {
    limbs : [u32; constants::NUM_LIMBS],
}

// TODO: impl
struct BigInt2 {
    limbs : [u32; constants::DOUBLE_LIMBS],
}

impl BigInt {
    /// Creation

    // Creates and initializes a BigInt.
    fn new(limbs : [u32; constants::NUM_LIMBS]) -> Self {
        Self {
            limbs: limbs
        }
    }

    // Returns the additive identity element
    fn zero() -> Self {
        BigInt::new([0 as u32; constants::NUM_LIMBS])
    }

    // Returns the multiplicative identity element
    fn one() -> Self {
        let mut one = [0 as u32; constants::NUM_LIMBS];
        one[0] = 1;
        BigInt::new(one)
    }
    
    // Returns the big integer representation of a given little endian byte array
    fn from_bytes_le(bytes : [u8]) -> Self {
        // The maximum number of bytes that can fit in this bigint
        let MAX_BYTES : comptime Field = constants::NUM_LIMBS * constants::LIMB_BYTES;
        let SHIFTS : [comptime u32; 4] = [
            constants::U32_POW_2_0,
            constants::U32_POW_2_8,
            constants::U32_POW_2_16,
            constants::U32_POW_2_24,
        ];

        let bytes_len = bytes.len() as u32;
        
        // TODO: Should we allow this?
        constrain bytes_len <= MAX_BYTES as u32;

        let mut limbs = [0 as u32; constants::NUM_LIMBS];
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

    // Creates and initializes a BigInt by selecting NUM_LIMBS consecutive limbs from an an array of size DOUBLE_LIMBS
    fn from_double_limbs(double_limbs : [u32; constants::DOUBLE_LIMBS], offset : u32) -> Self {
        constrain offset <= constants::NUM_LIMBS as u32;
        let mut limbs = [0 as u32; constants::NUM_LIMBS];
        for i in 0..constants::DOUBLE_LIMBS {
            if i as u32 == offset {
                for j in 0..constants::NUM_LIMBS {
                    limbs[j] = double_limbs[i + j];
                };
            }
        };
        BigInt::new(limbs)
    }
    
    /// Math

    // Returns last non-zero limb, its index as tuple (msl_index, msl).
    // Returns (0, 0) if self == BigInt::zero().
    fn most_significant_limb(self : Self) -> (u32, u32) {
        let mut msl_index = 0 as u32;
        let mut msl = 0 as u32;
        for i in 0..(constants::NUM_LIMBS) {
            let j = constants::NUM_LIMBS - i - 1;
            if (self.limbs[j] > 0) & (msl == 0) {
                msl_index = j as u32;
                msl = self.limbs[j];
            }
        };
        (msl_index, msl)
    }


    // Returns last non-zero limb, its index, and the limb before it as tuple (msl_index, msl_minus_one, msl).
    // Returns (0, 0, 0) if most_significant_limb index < 1.
    fn two_most_significant_limbs(self : Self) -> (u32, u32, u32) {
        let mut msl_index = 0 as u32;
        let mut msl = 0 as u32;
        let mut msl_minus_one = 0 as u32;
        for i in 0..(constants::NUM_LIMBS - 1) {
            let j = constants::NUM_LIMBS - i - 1;
            if (self.limbs[j] > 0) & (msl == 0) {
                msl_index = j as u32;
                msl = self.limbs[j];
                msl_minus_one = self.limbs[j - 1];
            }
        };
        (msl_index, msl_minus_one, msl)
    }

    // Returns last non-zero limb, its index, and the 2 limbs before it as tuple (msl_index, msl_minus_two, msl_minus_one, msl).
    // Returns (0, 0, 0, 0) if most_significant_limb index < 2.
    fn three_most_significant_limbs(self : Self) -> (u32, u32, u32, u32) {
        let mut msl_index = 0 as u32;
        let mut msl = 0 as u32;
        let mut msl_minus_one = 0 as u32;
        let mut msl_minus_two = 0 as u32;
        for i in 0..(constants::NUM_LIMBS - 2) {
            let j = constants::NUM_LIMBS - i - 1;
            if (self.limbs[j] > 0) & (msl == 0) {
                msl_index = j as u32;
                msl = self.limbs[j];
                msl_minus_one = self.limbs[j - 1];
                msl_minus_two = self.limbs[j - 2];
            }
        };
        (msl_index, msl_minus_two, msl_minus_one, msl)
    }
    
    fn add(self : Self, other : BigInt) -> (BigInt, u32) {
        let mut limbs : [u32; constants::NUM_LIMBS] = [0 as u32; constants::NUM_LIMBS];
        let mut carry : u32 = 0;
        for i in 0..constants::NUM_LIMBS {
            let (limb_sum, new_carry) = arithmetic::add_limbs_with_carry(self.limbs[i], other.limbs[i], carry);
            limbs[i] = limb_sum;
            carry = new_carry;
        };
        (BigInt::new(limbs), carry)
    }

    fn mul(self : Self, other : BigInt) -> BigInt2 {
        // Double limbs won't overflow because the product of two N-limb arrays is never larger than 2N-limbs
        // ((b^n) - 1) * ((b^n) - 1) = b^(2n) - 2(b^n) - 1 < b^(2n)
        let mut limbs  = [0 as u32; constants::DOUBLE_LIMBS];

        for i in 0..constants::NUM_LIMBS {
            let mut carry : u32 = 0;
            for j in 0..constants::NUM_LIMBS {
                let k = i + j;
                let (limb_product, new_carry) = arithmetic::mul_limbs_with_carry(limbs[k], self.limbs[i], other.limbs[j], carry);
                limbs[k] = limb_product;
                carry = new_carry;
            };
            limbs[i + constants::NUM_LIMBS] = carry;
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
    fn sub(self : Self, other : Self) -> (BigInt, u32) {
        let mut limbs : [u32; constants::NUM_LIMBS] = [0 as u32; constants::NUM_LIMBS];
        let mut borrow : u32 = 0;
        for i in 0..constants::NUM_LIMBS {
            let (limb_diff, new_borrow) = arithmetic::sub_limbs_with_borrow(self.limbs[i], other.limbs[i], borrow);
            limbs[i] = limb_diff;
            borrow = new_borrow;
        };
        
        (BigInt::new(limbs), borrow)
    }
    
    // 
    fn shift(self : Self, shift : u32, left : bool) -> BigInt {
        constrain shift < 8;
        let mut limbs = self.limbs;
        for i in 0..constants::NUM_LIMBS {
            if i as u32 < constants::NUM_LIMBS as u32 - shift {
                if left == true {
                    if shift == 1 {
                        limbs[i] = self.limbs[i + 1];
                    }
                    if shift == 2 {
                        limbs[i] = self.limbs[i + 2];
                    }
                    if shift == 3 {
                        limbs[i] = self.limbs[i + 3];
                    }
                    if shift == 4 {
                        limbs[i] = self.limbs[i + 4];
                    }
                    if shift == 5 {
                        limbs[i] = self.limbs[i + 5];
                    }
                    if shift == 6 {
                        limbs[i] = self.limbs[i + 6];
                    }
                    if shift == 7 {
                        limbs[i] = self.limbs[i + 7];
                    }
                } else {
                    if shift == 1 {
                        limbs[i + 1] = self.limbs[i];
                    }
                    if shift == 2 {
                        limbs[i + 2] = self.limbs[i];
                    }
                    if shift == 3 {
                        limbs[i + 3] = self.limbs[i];
                    }
                    if shift == 4 {
                        limbs[i + 4] = self.limbs[i];
                    }
                    if shift == 5 {
                        limbs[i + 5] = self.limbs[i];
                    }
                    if shift == 6 {
                        limbs[i + 6] = self.limbs[i];
                    }
                    if shift == 7 {
                        limbs[i + 7] = self.limbs[i];
                    }
                }
            } else {
                if left == true {
                    limbs[i] = 0;
                } else {
                    limbs[constants::NUM_LIMBS - i - 1] = 0;
                }
            }
        }
        BigInt::new(limbs)
    }

    // Returns self - (multiplicand * other).
    fn sub_mul(self : Self, limb_shift : u32, multiplicand : u32, other : BigInt) -> (BigInt, u32) {
        let shifted = self.shift(limb_shift, true);
        let mut limbs : [u32; constants::NUM_LIMBS] = [0 as u32; constants::NUM_LIMBS];
        let mut borrow : u32 = 0;
        for i in 0..constants::NUM_LIMBS {
            let (limb_diff, new_borrow) = arithmetic::sub_mul_limbs_with_borrow(shifted.limbs[i], multiplicand, other.limbs[i], borrow);
            limbs[i] = limb_diff;
            borrow = new_borrow;
        };
        let unshifted = BigInt::new(limbs).shift(limb_shift, false);
        let mut result = unshifted.limbs;
        for i in 0..constants::NUM_LIMBS {
            if i as u32 < limb_shift {
                result[i] = self.limbs[i];
            }
        };
        
        (BigInt::new(result), borrow)
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
        for i in 1..constants::NUM_LIMBS {
            if result == true {
                result = self.limbs[i] == 0;
            }
        };
        result
    }

    // Returns true iff this number is one.
    fn is_one(self : Self) -> bool {
        let mut result : bool = self.limbs[0] == 1;
        for i in 1..constants::NUM_LIMBS {
            if result == true {
                result = self.limbs[i] == 0;
            }
        };
        result
    }

    // Returns true iff this number >= other.
    fn gte(self : Self, other : Self) -> bool {
        let result = self.sub(other);
        let borrow = result.1;
        borrow == 0
    }

    // Returns true iff this number > other.
    fn gt(self : Self, other : Self) -> bool {
        let (difference, borrow) = self.sub(other);
        let difference_is_zero = difference.is_zero();
        (borrow == 0) & (difference_is_zero == false)
    }

    // Returns true iff this number <= other.
    fn lte(self : Self, other : Self) -> bool {
        other.gte(self)
    }

    // Returns true iff this number < other.
    fn lt(self : Self, other : Self) -> bool {
        other.gt(self)
    }

    // Returns true iff this number == other.
    fn eq(self : Self, other : Self) -> bool {
        let mut is_eq = true;
        for i in 0..constants::NUM_LIMBS {
            is_eq = is_eq & (self.limbs[i] == other.limbs[i]);
        }
        is_eq
    }
}


// Tests
/// from_bytes_be
#[test]
fn test_from_bytes_be_case1() {
    // TODO: this line causes a weird bug that I think is related to MAX_BYTES existing in a diff function
    // let MAX_BYTES : comptime Field = constants::NUM_LIMBS * constants::LIMB_BYTES;
    let bytes = [1 as u8, 0, 1];
    let bint = BigInt::from_bytes_le(bytes);
    constrain bint.limbs[0] == 1 + 65536;
    for i in 1..constants::NUM_LIMBS {
        constrain bint.limbs[i] == 0;
    };
}

#[test]
fn test_from_bytes_be_case2() {
    let bytes = [
        0 as u8, 0, 0, 0,
        0, 0, 0, 7,
    ];
    let bint = BigInt::from_bytes_le(bytes);
    constrain bint.limbs[0] == 0;
    constrain bint.limbs[1] == 117440512;
    for i in 2..constants::NUM_LIMBS {
        constrain bint.limbs[i] == 0;
    };
}

#[test]
fn test_from_double_limbs_case1() {
    let double_limbs : [u32; constants::DOUBLE_LIMBS] = [0 as u32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    let x = BigInt::from_double_limbs(double_limbs, constants::NUM_LIMBS as u32);
    constrain x.limbs == [8 as u32, 9, 10, 11, 12, 13, 14, 15];
}

#[test]
fn test_from_double_limbs_case2() {
    let double_limbs : [u32; constants::DOUBLE_LIMBS] = [0 as u32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    let x = BigInt::from_double_limbs(double_limbs, 0);
    constrain x.limbs == [0 as u32, 1, 2, 3, 4, 5, 6, 7];
    // TODO: Test offset bounds
}

// is_zero, is_one
#[test]
fn test_is_zero_case1() {
    let a = BigInt::new([0 as u32; constants::NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let zero = BigInt::zero();
    constrain a.is_zero() == true;
    constrain b.is_zero() == false;
    constrain zero.is_zero() == true;
}

#[test]
fn test_is_one_case1() {
    let a = BigInt::new([0 as u32; constants::NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let one = BigInt::one();
    constrain a.is_one() == false;
    constrain b.is_one() == true;
    constrain one.is_one() == true;
}

// add
#[test]
fn test_add_case1() {
    let a = BigInt::new([1 as u32; constants::NUM_LIMBS]);
    let b = BigInt::new([2 as u32; constants::NUM_LIMBS]);
    let expected_sum_limbs = [3 as u32; constants::NUM_LIMBS];
    let expected_overflow = 0;
    let (sum, overflow) = a.add(b);
    constrain sum.limbs == expected_sum_limbs;
    constrain overflow == expected_overflow;
}

#[test]
fn test_add_case2() {
    let a = BigInt::new([constants::U32_MAX as u32, constants::U32_MAX as u32, constants::U32_MAX as u32, 0, 0, 0, 0, 0]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_sum_limbs = [0, 0, 0, 1, 0, 0, 0, 0];
    let expected_overflow = 0;
    let (sum, overflow) = a.add(b);
    constrain sum.limbs == expected_sum_limbs;
    constrain overflow == expected_overflow;
}

#[test]
fn test_add_case3() {
    let a = BigInt::new([constants::U32_MAX as u32; constants::NUM_LIMBS]);
    let b = BigInt::new([1 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_sum_limbs = [0, 0, 0, 0, 0, 0, 0, 0];
    let expected_overflow = 1;
    let (sum, overflow) = a.add(b);
    constrain sum.limbs == expected_sum_limbs;
    constrain overflow == expected_overflow;
}

// sub
#[test]
fn test_sub_case1() {
    let a = BigInt::new([3 as u32; constants::NUM_LIMBS]);
    let b = BigInt::new([1 as u32; constants::NUM_LIMBS]);
    let expected_diff_limbs = [2 as u32; constants::NUM_LIMBS];
    let expected_overflow = 0;
    let (difference, overflow) = a.sub(b);
    constrain difference.limbs == expected_diff_limbs;
    constrain overflow == expected_overflow;
}

#[test]
fn test_sub_case2() {
    let a = BigInt::new([4 as u32, 2, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_diff_limbs : [u32; 8] = [constants::U32_MAX as u32, 1, 0, 0, 0, 0, 0, 0];
    let expected_overflow = 0;
    let (difference, overflow) = a.sub(b);
    constrain difference.limbs == expected_diff_limbs;
    constrain overflow == expected_overflow;
}

#[test]
fn test_sub_case3() {
    let a = BigInt::new([4 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_diff_limbs : [u32; 8] = [constants::U32_MAX as u32; 8];
    let expected_overflow = 1;
    let (difference, overflow) = a.sub(b);
    constrain difference.limbs == expected_diff_limbs;
    constrain overflow == expected_overflow;
}

// mul
#[test]
fn test_mul_case1() {
    let a = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5 as u32, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs = [25 as u32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    let product = a.mul(b);
    constrain product.limbs == expected_product_limbs;
}

#[test]
fn test_mul_case2() {
    let a = BigInt::new([constants::U32_MAX; constants::NUM_LIMBS]);
    let b = BigInt::new([constants::U32_MAX; constants::NUM_LIMBS]);
    let expected_product_limbs = [1 as u32, 0, 0, 0, 0, 0, 0, 0, 4294967294, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295];
    let product = a.mul(b);
    constrain product.limbs == expected_product_limbs;
}

// sub_mul
#[test]
fn test_sub_mul_case1() {
    let a = BigInt::new([constants::U32_MAX, constants::U32_MAX, constants::U32_MAX, 0, 0, 0, 0, 0]);
    let b = constants::U32_MAX;
    let c = BigInt::new([constants::U32_MAX, constants::U32_MAX, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [constants::U32_MAX - 1, 0, 1, 0, 0, 0, 0, 0];
    let (product, overflow) = a.sub_mul(0, b, c);
    constrain product.limbs == expected_product_limbs;
    constrain overflow == 0;
}

#[test]
fn test_sub_mul_case2() {
    let a = BigInt::new([0, 0, 0, 0, 1, 0, 0, 0]);
    let b = 2147483645;
    let c = BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [0, 2147483675, 2147483670, 1, 0, 0, 0, 0];
    let (product, overflow) = a.sub_mul(1, b, c);
    constrain product.limbs == expected_product_limbs;
    constrain overflow == 0;
}

#[test]
fn test_sub_mul_case3() {
    let a = BigInt::new([0, 0, 0, 0, 1, 0, 0, 0]);
    let b = 0;
    let c = BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [0, 0, 0, 0, 1, 0, 0, 0];
    let (product, overflow) = a.sub_mul(2, b, c);
    constrain product.limbs == expected_product_limbs;
    constrain overflow == 0;
}

// msl
#[test]
fn test_msl_case1() {
    let a = BigInt::new([constants::U32_MAX, constants::U32_MAX, constants::U32_MAX, 0, 0, 0, 0, 0]);
    let expected_msl_index = 2;
    let expected_msl : u32 = a.limbs[2];
    let expected_msl_minus_one = a.limbs[1];
    let (msl_index, msl_minus_one , msl) = a.two_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
}

#[test]
fn test_msl_case2() {
    let a = BigInt::new([constants::U32_MAX, constants::U32_MAX, constants::U32_MAX, 0, 0, 0, 0, 1]);
    let expected_msl_index = 7;
    let expected_msl : u32 = 1;
    let expected_msl_minus_one = 0;
    let (msl_index, msl_minus_one , msl) = a.two_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
}

#[test]
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

#[test]
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

#[test]
fn test_msl_case5() {
    let a = BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    let expected_msl_index = 2;
    let expected_msl = 2;
    let expected_msl_minus_one = 9;
    let expected_msl_minus_two = 9;
    let (msl_index, msl_minus_two, msl_minus_one , msl) = a.three_most_significant_limbs();
    constrain expected_msl_index == msl_index;
    constrain expected_msl == msl;
    constrain expected_msl_minus_one == msl_minus_one;
    constrain expected_msl_minus_two == msl_minus_two;
}

// cmp
#[test]
fn test_cmp() {
    let x1 = BigInt::new([0 as u32, 0, 0, 0, 1, 0, 0, 0]);
    let y1 = BigInt::new([0 as u32, 0, 0, 0, 0, 0, 0, 1]);
    constrain x1.lt(y1) == true;
    constrain x1.lte(y1) == true;
    constrain x1.gt(y1) == false;
    constrain x1.gte(y1) == false;
    constrain x1.eq(y1) == false;

    let x2 = BigInt::new([0 as u32, 0, 0, 0, 0, 0, 0, 1]);
    let y2 = BigInt::new([0 as u32, 0, 0, 0, 1, 0, 0, 1]);
    constrain x2.lt(y2) == true;
    constrain x2.lte(y2) == true;
    constrain x2.gt(y2) == false;
    constrain x2.gte(y2) == false;
    constrain x2.eq(y2) == false;

    let x3 = BigInt::new([0 as u32, 0, 0, 0, 1, 0, 0, 2]);
    let y3 = BigInt::new([0 as u32, 0, 0, 0, 2, 0, 0, 1]);
    constrain x3.lt(y3) == false;
    constrain x3.lte(y3) == false;
    constrain x3.gt(y3) == true;
    constrain x3.gte(y3) == true;
    constrain x3.eq(y3) == false;

    let x4 = BigInt::new([0 as u32, 0, 0, 0, 2, 0, 0, 2]);
    let y4 = BigInt::new([0 as u32, 0, 0, 0, 2, 0, 0, 2]);
    constrain x4.lt(y4) == false;
    constrain x4.lte(y4) == true;
    constrain x4.gt(y4) == false;
    constrain x4.gte(y4) == true;
    constrain x4.eq(y4) == true;
}

#[test]
fn test_shift() {
    let x = BigInt::new([0 as u32, 1, 0, 0, 1, 0, 0, 0]);

    let left_shift_0 = x.shift(0, true);
    constrain left_shift_0.limbs == [0, 1, 0, 0, 1, 0, 0, 0];
    let left_shift_1 = x.shift(1, true);
    constrain left_shift_1.limbs == [1, 0, 0, 1, 0, 0, 0, 0];
    let left_shift_2 = x.shift(2, true);
    constrain left_shift_2.limbs == [0, 0, 1, 0, 0, 0, 0, 0];
    let left_shift_3 = x.shift(3, true);
    constrain left_shift_3.limbs == [0, 1, 0, 0, 0, 0, 0, 0];
    let left_shift_4 = x.shift(4, true);
    constrain left_shift_4.limbs == [1, 0, 0, 0, 0, 0, 0, 0];
    let left_shift_7 = x.shift(7, true);
    constrain left_shift_7.limbs == [0, 0, 0, 0, 0, 0, 0, 0];

    let y = BigInt::new([7 as u32, 0, 0, 0, 0, 3, 0, 0]);
    let right_shift_0 = y.shift(0, false);
    constrain right_shift_0.limbs == [7, 0, 0, 0, 0, 3, 0, 0];
    let right_shift_1 = y.shift(1, false);
    constrain right_shift_1.limbs == [0, 7, 0, 0, 0, 0, 3, 0];
    let right_shift_2 = y.shift(2, false);
    constrain right_shift_2.limbs == [0, 0, 7, 0, 0, 0, 0, 3];
    let right_shift_3 = y.shift(3, false);
    constrain right_shift_3.limbs == [0, 0, 0, 7, 0, 0, 0, 0];
    let right_shift_4 = y.shift(4, false);
    constrain right_shift_4.limbs == [0, 0, 0, 0, 7, 0, 0, 0];
    let right_shift_7 = y.shift(7, false);
    constrain right_shift_7.limbs == [0, 0, 0, 0, 0, 0, 0, 7];
}
