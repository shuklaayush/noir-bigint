use dep::bigint;

fn main(x : [u32; bigint::constants::NUM_LIMBS], y : [u32; bigint::constants::NUM_LIMBS]) -> pub u32 {
    assert(x != y);
    // let x_as_bigint = BigInt::new(x);
    // let y_as_bigint = BigInt::new(y);
    // let product = x_as_bigint.mul(y_as_bigint);
    // let expected_product_limbs = [1 as u32, 0, 0, 0, 0, 0, 0, 0, 4294967294, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295];
    // assert(product.limbs == expected_product_limbs);
    bigint::run_tests();
    // let a = bigint::BigInt::new(x);
    // let (a_msl_index, a2, a1, a0) = a.three_most_significant_limbs();
    // let b = bigint::BigInt::new(y);
    // let (b_msl_index, b1, b0) = b.two_most_significant_limbs();
    // let b = bigint::BigInt::new([9, 9, 2, 0, 0, 0, 0, 0]);
    // let result = bigint::division::div_wide(a.limbs[4], a.limbs[3], a.limbs[2], b.limbs[2], b.limbs[1]);
    // let a_trip = bigint::division::to_triple_limb(a0, a1, a2);
    // let b_trip = bigint::division::to_triple_limb(0, b0, b1);
    // let a_trip = ((a.limbs[4] as u96 * bigint::division::U96_POW_2_64) + (a.limbs[3] as u96 * bigint::division::U96_POW_2_32) + a.limbs[2] as u96);
    // let b_trip = ((b.limbs[2] as u96 * bigint::division::U96_POW_2_32) + b.limbs[1] as u96);
    // let q = a_trip / b_trip;
    // let r = lhs - (rhs * q);
    // let d = (a.limbs[4] & a.limbs[3]) + 1 - 1;
    // let e = (b.limbs[2] | b.limbs[1]) + 1 - 1;
    // let c = (a.limbs[4] & a.limbs[3]) / (b.limbs[2] | b.limbs[1]);
    
    bigint::constants::U64_LOWER_32_BITS as u32
    // let q = bigint::div_rem_core(a, b);
    // let x = a.mul(b);
    // x.limbs[2]
    // assert(q.limbs[0] == 3221225479);
    // assert(q.limbs[1] == 2147483645);
    // assert(q.limbs[2] == 0);
    // q.limbs[0]
    // a.limbs[0]
    // q.overflow
    // result.0
}