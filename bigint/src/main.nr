mod bigint;

fn main(x : [u32; bigint::NUM_LIMBS], y : [u32; bigint::NUM_LIMBS]) {
    constrain x == y;
    // let x_as_bigint = BigInt::new(x);
    // let y_as_bigint = BigInt::new(y);
    // let product = x_as_bigint.mul(y_as_bigint);
    // let expected_product_limbs = [1 as u32, 0, 0, 0, 0, 0, 0, 0, 4294967294, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295, 4294967295];
    // constrain product.limbs == expected_product_limbs;
    bigint::run_tests();
}