global U64_LOWER_32_BITS : u64 = 4294967295;
global U64_UPPER_32_BITS : u64 = 18446744069414584320;
global U64_POW_2_32 : u64 = 4294967296;

// returns sum = a + b + carry, and the new carry.
fn add_limbs_with_carry(a: u32, b: u32, carry: u32) -> (u32, u32) {
    let sum : u64 = a as u64 + b as u64 + carry as u64;
    let new_carry : u32 = ((sum & U64_UPPER_32_BITS) / U64_POW_2_32) as u32;
    ((sum & U64_LOWER_32_BITS) as u32, new_carry)
}

// Returns diff = a - b - borrow, and the new borrow.
fn sub_limbs_with_borrow(a: u32, b: u32, borrow: u32) -> (u32, u32) {
    let diff_with_overflow : u64 = (U64_POW_2_32 as u64) + (a as u64) - (b as u64) - (borrow as u64);
    let diff = diff_with_overflow & U64_LOWER_32_BITS;
    if diff_with_overflow < U64_POW_2_32 {
        // Borrow was necessary
        ((diff & U64_LOWER_32_BITS) as u32, 1 as u32)
    } else {
        ((diff & U64_LOWER_32_BITS) as u32, 0 as u32)
    }
}

// returns product = (a * b) + carry, and the new carry.
fn mul_limbs_with_carry(a: u32, b: u32, carry: u32) -> (u32, u32) {
    let product : u64 = a as u64 * b as u64 + carry as u64;
    let new_carry : u32 = ((product & U64_UPPER_32_BITS) / U64_POW_2_32) as u32;
    ((product & U64_LOWER_32_BITS) as u32, new_carry)
}

// fn bytes_mul(multiplicand : [u8; BYTES_ARRAY_LENGTH], multiplier : [u8; BYTES_ARRAY_LENGTH]) -> [u8; TWO_BYTES_ARRAY_LENGTH] {

// Tests
fn run_tests() {
    test_add_limbs();
    test_sub_limbs();
}

// add_limbs_with_carry
fn test_add_limbs_with_carry_case1() {
    let a = 1;
    let b = 4294967295; // 2^32 - 1
    let expected_sum = 0;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, 0);
    constrain sum == expected_sum;
    constrain new_carry == expected_new_carry;
}

fn test_add_limbs_with_carry_case2() {
    let a = 99;
    let b = 4294967295; // 2^32 - 1
    let expected_sum = 98;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, 0);
    constrain sum == expected_sum;
    constrain new_carry == expected_new_carry;
}

fn test_add_limbs_with_carry_case3() {
    let a = 5;
    let b = 10;
    let carry = 7;
    let expected_sum = 22;
    let expected_new_carry = 0;
    let (sum, new_carry) = add_limbs_with_carry(a, b, carry);
    constrain sum == expected_sum;
    constrain new_carry == expected_new_carry;
}

fn test_add_limbs_with_carry_case4() {
    let a = 4294967295; // 2^32 - 1
    let b = 0;
    let carry = 1;
    let expected_sum = 0;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, carry);
    constrain sum == expected_sum;
    constrain new_carry == expected_new_carry;
}

fn test_add_limbs() {
    test_add_limbs_with_carry_case1();
    test_add_limbs_with_carry_case2();
    test_add_limbs_with_carry_case3();
    test_add_limbs_with_carry_case4();
}

//sub_limbs_with_borrow 
fn test_sub_limbs_with_borrow_case1() {
    let a = 5;
    let b = 3;
    let expected_diff = 2;
    let expected_new_borrow = 0;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, 0);
    constrain diff == expected_diff;
    constrain new_borrow == expected_new_borrow;
}

fn test_sub_limbs_with_borrow_case2() {
    let a = 0;
    let b = 1;
    let expected_diff = (U64_POW_2_32 - 1) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, 0);
    constrain diff == expected_diff;
    constrain new_borrow == expected_new_borrow;
}

fn test_sub_limbs_with_borrow_case3() {
    let a = 0;
    let b = 1;
    let borrow = 1;
    let expected_diff = (U64_POW_2_32 - 2) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    constrain diff == expected_diff;
    constrain new_borrow == expected_new_borrow;
}

fn test_sub_limbs_with_borrow_case4() {
    let a = 1000;
    let b = 44;
    let borrow = 1;
    let expected_diff = 955;
    let expected_new_borrow = 0;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    constrain diff == expected_diff;
    constrain new_borrow == expected_new_borrow;
}

fn test_sub_limbs_with_borrow_case5() {
    let a = (U64_POW_2_32 - 1) as u32;
    let b = (U64_POW_2_32 - 1) as u32;
    let borrow = 1;
    let expected_diff = (U64_POW_2_32 - 1) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    constrain diff == expected_diff;
    constrain new_borrow == expected_new_borrow;
}


fn test_sub_limbs() {
    test_sub_limbs_with_borrow_case1();
    test_sub_limbs_with_borrow_case2();
    test_sub_limbs_with_borrow_case3();
    test_sub_limbs_with_borrow_case4();
    test_sub_limbs_with_borrow_case5();
}
