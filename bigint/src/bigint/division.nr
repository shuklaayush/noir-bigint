// Limb helpers (maybe turn into a struct)
global U96_POW_2_32 : u96 = 4294967296;
global U96_POW_2_64 : u96 = 18446744073709551616;
fn to_triple_limb(hi : u32, mid : u32, lo : u32) -> u96 {
    (hi as u96 * U96_POW_2_64) | (mid as u96 * U96_POW_2_32) | (lo as u96)
}

/// Divide a three limb numerator by a two limb divisor, returns quotient and remainder:
///
/// Note: the caller must ensure that both the quotient and remainder will fit into a single digit.
/// This is _not_ true for an arbitrary numerator/denominator.
fn div_wide(dividend_hi: u32, dividend_mid: u32, dividend_lo: u32, divisor_mid: u32, divisor_lo: u32) -> (u32, u64) {
    // TODO: debug_assert!(hi < divisor);
    let lhs = to_triple_limb(dividend_hi, dividend_mid, dividend_lo);
    let rhs = to_triple_limb(0, divisor_mid, divisor_lo);
    let q = lhs / rhs;
    let r = lhs - (rhs * q);
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

/// Tests
fn run_tests() {
    test_div_wide();
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

fn test_div_wide() {
    test_div_wide_case1();
}
