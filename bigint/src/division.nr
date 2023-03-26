use dep::std;
use crate::constants;
use crate::BigInt;

fn to_triple_limb(hi : u32, mid : u32, lo : u32) -> u96 {
    // (hi as u96 * constants::U96_POW_2_64) | (mid as u96 * constants::U96_POW_2_32) | (lo as u96)
    (hi as u96 * constants::U96_POW_2_64) + (mid as u96 * constants::U96_POW_2_32) + (lo as u96)
}

fn from_triple_limb(trip : u96) -> (u32, u32, u32) {
    ((trip / constants::U96_POW_2_64) as u32, ((trip * constants::U96_POW_2_32) / constants::U96_POW_2_64) as u32, ((trip * constants::U96_POW_2_64) / constants::U96_POW_2_64) as u32)
}

/// Divide a three limb numerator by a two limb divisor, returns quotient and remainder:
///
/// Note: the caller must ensure that both the quotient and remainder will fit into a single digit.
/// This is _not_ true for an arbitrary numerator/denominator.
fn div_wide(dividend_hi: u32, dividend_mid: u32, dividend_lo: u32, divisor_mid: u32, divisor_lo: u32) -> (u32, u64) {
    let dividend = to_triple_limb(dividend_hi, dividend_mid, dividend_lo);
    let divisor = to_triple_limb(0, divisor_mid, divisor_lo);
    let q = dividend / divisor;
    let r = dividend - (divisor * q);
    (q as u32, r as u64)
}

/// Similar to div_wide but returns double_limbs so we don't have to worry about overflow
fn div_wide_allow_overflow(dividend_hi: u32, dividend_mid: u32, dividend_lo: u32, divisor_hi: u32, divisor_mid: u32, divisor_lo: u32) -> (u32, u32, u32, u32, u32, u32) {
    let dividend = to_triple_limb(dividend_hi, dividend_mid, dividend_lo);
    let divisor = to_triple_limb(divisor_hi, divisor_mid, divisor_lo);
    let q = dividend / divisor;
    let r = dividend - (divisor * q);
    let (q_hi, q_med, q_lo) = from_triple_limb(q);
    let (r_hi, r_med, r_lo) = from_triple_limb(r);
    (q_hi, q_med, q_lo, r_hi, r_med, r_lo)
}

// /// Excerpted from https://docs.rs/num-bigint/latest/src/num_bigint/biguint/division.rs.html#210
// /// An implementation of the base division algorithm.
// /// Knuth, TAOCP vol 2 section 4.3.1, algorithm D, with an improvement from exercises 19-21.
fn div_rem_core(mut a: BigInt, b: BigInt) -> (BigInt, BigInt) {
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
    let (a_msl_index, mut a2, mut a1) = a.two_most_significant_limbs();
    if (a_msl_index == 0) {
        a2 = a.limbs[0];
        a1 = a.limbs[1];
    }

    // [b1, b0] are the two most significant digits of the divisor. They never change.
    let (b_msl_index, mut b1, mut b0) = b.two_most_significant_limbs();
    if (b_msl_index == 0) {
        b1 = b.limbs[0];
        b0 = b.limbs[1];
    }

    let q_len = a_msl_index - b_msl_index + 1;
    let mut q_limbs = [0 as u32; constants::NUM_LIMBS];
    
    for i in 0..constants::NUM_LIMBS {
        let j = constants::NUM_LIMBS - i - 1;
        if j as u32 < q_len {
            // The first q_estimate is [a2,a1,a0] / [b1,b0]. It will never be too small, it may be too large
            // by at most 1.
            let mut q_estimate = 0 as u32;
            let mut r = 0 as u64;
            
            // This if check is necessary to prevent div_wide from overflowing
            if (a0 < b0) {
                let result = div_wide(a0, a1, a2, b0, b1);
                q_estimate = result.0;
                r = result.1;
            } else {
                // Prefix with 0 to avoid overflowing q_estimate
                let result = div_wide(0, a0, a1, b0, b1);
                q_estimate = result.0;
                r = result.1;
            };
            // q_estimate is now either the correct quotient limb, or 1 too large.
            // Subtract (q_estimate << j) * b from a. This may overflow, in which case we will have to correct.
            let (sub_mul_result, sub_mul_overflow) = a.sub_mul(j as u32, q_estimate, b);
            a = sub_mul_result;
            let mut borrow = sub_mul_overflow;

            if borrow > 0 {
                // q_estimate is too large. We need to add back one multiple of b.
                q_estimate = q_estimate - 1;
                let (sum, sum_overflow) = a.add(b);
                a = sum;
                borrow = borrow - sum_overflow;
            }

            q_limbs[j] = q_estimate;

            // Don't do this on the last iteration when the quotient is fully formed
            if j != 0 {
                let (a_msl_index_update, mut a2_update, mut a1_update, mut a0_update) = a.three_most_significant_limbs();
                // In the case where the most significant limb index is not >= 2 we should just use the first
                // three limbs of the bigint
                if (a_msl_index_update == 0) {
                    a2_update = a.limbs[0];
                    a1_update = a.limbs[1];
                    a0_update = a.limbs[2];
                }
                a0 = a0_update;
                a1 = a1_update;
                a2 = a2_update;
            }
        }
    };
    (BigInt::new(q_limbs), a)
}

fn div_rem(a: BigInt, mut b: BigInt) -> (BigInt, BigInt) {
    let divisor_is_zero = b.is_zero();
    constrain divisor_is_zero == false;
    let mut result : (BigInt, BigInt) = (BigInt::zero(), BigInt::zero());
    let mut result_set : bool = false;

    let divisor_is_one = b.is_one();
    if !result_set & divisor_is_one {
        result = (a, BigInt::zero());
        result_set = true;
    }
    let dividend_is_zero = a.is_zero();
    if !result_set & dividend_is_zero {
        result = (BigInt::zero(), BigInt::zero());
        result_set = true;
    }
    let a_lt_b = a.lt(b);
    if !result_set & a_lt_b {
        result = (BigInt::zero(), a);
        result_set = true;
    }
    let a_eq_b = a.eq(b);
    if !result_set & a_eq_b {
        result = (BigInt::one(), BigInt::zero());
        result_set = true;
    }
    let a_msl_result = a.most_significant_limb();
    let b_msl_result = b.most_significant_limb();

    // If bigints will fit inside triple limb just divide them directly
    if !result_set & (a_msl_result.0 < 3) & (b_msl_result.0 < 3) {
        let straight_div_result = div_wide_allow_overflow(
            a.limbs[2],
            a.limbs[1],
            a.limbs[0],
            b.limbs[2],
            b.limbs[1],
            b.limbs[0],
        );
        result = (
            BigInt::new([straight_div_result.2, straight_div_result.1, straight_div_result.0, 0, 0, 0, 0, 0]),
            BigInt::new([straight_div_result.5, straight_div_result.4, straight_div_result.3, 0, 0, 0, 0, 0]),
        );
        result_set = true;
    }

    if !result_set {
        // When divisor is single digit we shift both the divisor and the resulting quotient
        if b_msl_result.0 == 0 {
            b = b.shift(1, false);
        }
        result = div_rem_core(a, b);
        if b_msl_result.0 == 0 {
            result = (result.0.shift(1, false), result.1);
        }
        result_set = true;
    }
    result
}

/// Tests

// div_wide
#[test]
fn test_div_wide_case1() {
    let dividend_hi = 1;
    let dividend_mid = 0;
    let dividend_lo = 0;
    let divisor_mid = 5;
    let divisor_lo = 139;
    let expected_q = 858993453;
    let expected_r = 13743896209;
    let (q, r) = div_wide(dividend_hi, dividend_mid, dividend_lo, divisor_mid, divisor_lo);
    constrain expected_q == q;
    constrain expected_r == r;
}

#[test]
fn test_div_wide_case2() {
    let dividend_hi = 1;
    let dividend_mid = 2147483670;
    let dividend_lo = 2147483675;
    let divisor_mid = 2;
    let divisor_lo = 9;
    let expected_q = 3221225479;
    let expected_r = 7516192732;
    let (q, r) = div_wide(dividend_hi, dividend_mid, dividend_lo, divisor_mid, divisor_lo);
    constrain expected_q == q;
    constrain expected_r == r;
}


// div_rem_core
#[test]
fn test_div_rem_case1() {
    let a = BigInt::new([0, 0, 0, 0, 1, 0, 0, 0]);
    let b = BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [3221225479, 2147483645, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [1073741761, 3221225429, 1, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case2() {
    let a = BigInt::new([75, 1, 1, 1, 0, 0, 0, 0]);
    let b = BigInt::new([0, 1, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [1, 1, 1, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [75, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case3() {
    let a = BigInt::new([75, 1, 1, 1, 0, 0, 0, 0]);
    let b = BigInt::new([75, 1, 1, 1, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [1, 0, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case4() {
    let a = BigInt::new([75, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([75, 1, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [75, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case5() {
    let a = BigInt::new([11, 0, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([5, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [2, 0, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [1, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}


#[test]
fn test_div_rem_case6() {
    let a = BigInt::new([0, 1, 0, 0, 0, 0, 0, 0]);
    let b = BigInt::new([2, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [2147483648, 0, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}


#[test]
fn test_div_rem_case7() {
    let a = BigInt::new([0, 0, 0, 0, 0, 0, 0, 1]);
    let b = BigInt::new([2, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [0, 0, 0, 0, 0, 0, 2147483648, 0];
    let expected_remainder : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case8() {
    let a = BigInt::new([0, 0, 1, 0, 0, 0, 0, 0]);
    let b = BigInt::new([2, 0, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [0, 2147483648, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_rem_case9() {
    let a = BigInt::new([0, 0, 1, 0, 0, 0, 0, 0]);
    let b = BigInt::new([0, 2, 0, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [2147483648, 0, 0, 0, 0, 0, 0, 0];
    let expected_remainder : [u32; 8] = [0, 0, 0, 0, 0, 0, 0, 0];
    let (q, r) = div_rem(a, b);
    constrain expected_product_limbs == q.limbs;
    constrain expected_remainder == r.limbs;
}

#[test]
fn test_div_wide_allow_overflow_case1() {
    let (q_hi, q_med, q_lo, r_hi, r_med, r_lo) = div_wide_allow_overflow(
        1, 0, 0,
        0, 0, 2,
    );
    constrain q_hi == 0;
    constrain q_med == 2147483648;
    constrain q_lo == 0;
    constrain r_hi == 0;
    constrain r_med == 0;
    constrain r_lo == 0;
}