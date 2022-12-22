// Tests
fn run_tests() {
    test_from_bytes_be();
    // test_add();
    // test_mul();
    // test_sub();
    // test_sub_mul();
    // test_msl();
    // test_div_wide();
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