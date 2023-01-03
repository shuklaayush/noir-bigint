use crate::constants;
use crate::BigInt;

// TODO: Blocked by https://github.com/noir-lang/noir/issues/580
// fn to_triple_limb(hi : u32, mid : u32, lo : u32) -> u96 {
//     // (hi as u96 * constants::U96_POW_2_64) | (mid as u96 * constants::U96_POW_2_32) | (lo as u96)
//     (hi as u96 * constants::U96_POW_2_64) + (mid as u96 * constants::U96_POW_2_32) + (lo as u96)
// }

/// Divide a three limb numerator by a two limb divisor, returns quotient and remainder:
///
/// Note: the caller must ensure that both the quotient and remainder will fit into a single digit.
/// This is _not_ true for an arbitrary numerator/denominator.
fn div_wide(dividend_hi: u32, dividend_mid: u32, dividend_lo: u32, divisor_mid: u32, divisor_lo: u32) -> (u32, u64) {
    // TODO: debug_assert!(hi < divisor);
    let dividend = (dividend_hi as u96 * constants::U96_POW_2_64) + (dividend_mid as u96 * constants::U96_POW_2_32) + (dividend_lo as u96);
    let divisor = (divisor_mid as u96 * constants::U96_POW_2_32) + (divisor_lo as u96);
    let q = dividend / divisor;
    let r = dividend - (divisor * q);
    (q as u32, r as u64)
}

/// For small divisors, we can divide without promoting to `DoubleBigDigit` by
/// using half-size pieces of digit, like long-division.
// fn div_half(rem: u32, digit: u32, divisor: u32) -> (u32, u32) {
//     // TODO: debug_assert!(rem < divisor && divisor <= HALF);
//     let (hi, rem) = ((rem << HALF_BITS) | (digit >> HALF_BITS)).div_rem(&divisor);
//     let (lo, rem) = ((rem << HALF_BITS) | (digit & HALF)).div_rem(&divisor);
//     ((hi << HALF_BITS) | lo, rem)
// }

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
    let mut q_limbs = [0 as u32; constants::NUM_LIMBS];
    
    for i in 0..constants::NUM_LIMBS {
        let j = constants::NUM_LIMBS - i - 1;
        if j as u32 < q_len {
            // TODO: debug_assert!(a.data.len() == b.len() + j);
            // The first q_estimate is [a2,a1,a0] / [b1,b0]. It will never be too small, it may be too large
            // by at most 1.
            let mut q_estimate = 0 as u32;
            let mut r = 0 as u64;
            if a0 < b0 {
                // let result = division::div_wide(a0, a1, a2, b0, b1);
                let a_trip = (a0 as u96 * constants::U96_POW_2_64) + (a1 as u96 * constants::U96_POW_2_32) + (a2 as u96);
                let b_trip = (b0 as u96 * constants::U96_POW_2_32) + (b1 as u96);
                let q_estimate_u96 = a_trip / b_trip;
                q_estimate = q_estimate_u96 as u32;
                r = (a_trip - (b_trip * q_estimate_u96)) as u64;
                // (q as u32, r as u64)
                // q_estimate = result.0;
                // r = result.1;
            } else {
                // TODO: debug_assert!(a0 == b0);
                // Avoid overflowing q_estimate
                // [a1,a0] = b0 * (1<<BITS - 1) + (a0 + a1)
                // (big_digit::MAX, a0 as DoubleBigDigit + a1 as DoubleBigDigit)
            };
            // q_estimate is now either the correct quotient limb, 1 too large.
            // Subtract (q_estimate << j) * b from a. This may overflow, in which case we will have to correct.

            // let mut borrow = sub_mul_digit_same_len(&mut a.data[j..], b, q0);
            let (sub_mul_result, sub_mul_overflow) = a.sub_mul(j as u32, q_estimate, b);
            a = sub_mul_result;
            let mut borrow = sub_mul_overflow;
            
            // This is necesary because of this bug https://github.com/noir-lang/noir/issues/579
            // let mut a_limbs = a.limbs;

            if borrow > 0 {
                // q_estimate is too large. We need to add back one multiple of b.
                q_estimate = q_estimate - 1;
                let (sum, sum_overflow) = a.add(b);
                a = sum;
                borrow = borrow - sum_overflow;
            }
            // a = BigInt::new(a_limbs);

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

/// Tests
fn run_tests() {
    test_div_wide();
    test_div_rem_core();
}

// div_wide
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


fn test_div_wide() {
    test_div_wide_case1();
    test_div_wide_case2();
}

// div_rem_core
fn test_div_rem_core_case1() {
    let a = BigInt::new([0, 0, 0, 0, 1, 0, 0, 0]);
    let b = BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    let expected_product_limbs : [u32; 8] = [3221225479, 2147483645, 0, 0, 0, 0, 0, 0];
    let q = div_rem_core(a, b);
    constrain expected_product_limbs == q.limbs;
}

fn test_div_rem_core() {
    test_div_rem_core_case1();
}