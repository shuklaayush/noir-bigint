use crate::constants;

// returns sum = a + b + carry, and the new carry.
fn add_limbs_with_carry(a: u32, b: u32, carry: u32) -> (u32, u32) {
    let sum = a as u33 + b as u33 + carry as u33;
    let new_carry = (sum >> (constants::LIMB_BITS as comptime u33)) as u32;
    (sum as u32, new_carry)
}

// Returns diff = a - b - borrow, and the new borrow.
fn sub_limbs_with_borrow(a: u32, b: u32, borrow: u32) -> (u32, u32) {
    let diff_with_overflow = (1 << constants::LIMB_BITS as comptime u33) + a as u33 - b as u33 - borrow as u33;
    let new_borrow = 1 - (diff_with_overflow >> (constants::LIMB_BITS as comptime u33)) as u32;
    (diff_with_overflow as u32, new_borrow)
}

// TODO: Tests for max b and 0 b
// Returns diff = a - (b * c) - borrow, and the new borrow.
fn sub_mul_limbs_with_borrow(a: u32, b: u32, c: u32, borrow: u32) -> (u32, u32) {
    let diff_with_overflow : u64 = constants::U64_UPPER_32_BITS + (a as u64) - (b as u64 * c as u64) - (borrow as u64);
    let diff = diff_with_overflow as u32;
    let new_borrow = ((constants::U64_UPPER_32_BITS - (diff_with_overflow & constants::U64_UPPER_32_BITS)) >> constants::LIMB_BITS) as u32;
    (diff, new_borrow)
}

// returns a + (b * c) + carry, and the new carry.
fn mul_limbs_with_carry(a: u32, b: u32, c: u32, carry: u32) -> (u32, u32) {
    let calc_result : u64 = a as u64 + (b as u64 * c as u64) + carry as u64;
    let new_carry = (calc_result >> constants::LIMB_BITS) as u32;
    (calc_result as u32, new_carry)
}

// Tests

// add_limbs_with_carry
#[test]
fn test_add_limbs_with_carry_case1() {
    let a = 1;
    let b = 4294967295; // 2^32 - 1
    let expected_sum = 0;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, 0);
    assert(sum == expected_sum);
    assert(new_carry == expected_new_carry);
}

#[test]
fn test_add_limbs_with_carry_case2() {
    let a = 99;
    let b = 4294967295; // 2^32 - 1
    let expected_sum = 98;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, 0);
    assert(sum == expected_sum);
    assert(new_carry == expected_new_carry);
}

#[test]
fn test_add_limbs_with_carry_case3() {
    let a = 5;
    let b = 10;
    let carry = 7;
    let expected_sum = 22;
    let expected_new_carry = 0;
    let (sum, new_carry) = add_limbs_with_carry(a, b, carry);
    assert(sum == expected_sum);
    assert(new_carry == expected_new_carry);
}

#[test]
fn test_add_limbs_with_carry_case4() {
    let a = 4294967295; // 2^32 - 1
    let b = 0;
    let carry = 1;
    let expected_sum = 0;
    let expected_new_carry = 1;
    let (sum, new_carry) = add_limbs_with_carry(a, b, carry);
    assert(sum == expected_sum);
    assert(new_carry == expected_new_carry);
}

//sub_limbs_with_borrow 
#[test]
fn test_sub_limbs_with_borrow_case1() {
    let a = 5;
    let b = 3;
    let expected_diff = 2;
    let expected_new_borrow = 0;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, 0);
    assert(diff == expected_diff);
    assert(new_borrow == expected_new_borrow);
}

#[test]
fn test_sub_limbs_with_borrow_case2() {
    let a = 0;
    let b = 1;
    let expected_diff = (constants::U64_POW_2_32 - 1) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, 0);
    assert(diff == expected_diff);
    assert(new_borrow == expected_new_borrow);
}

#[test]
fn test_sub_limbs_with_borrow_case3() {
    let a = 0;
    let b = 1;
    let borrow = 1;
    let expected_diff = (constants::U64_POW_2_32 - 2) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    assert(diff == expected_diff);
    assert(new_borrow == expected_new_borrow);
}

#[test]
fn test_sub_limbs_with_borrow_case4() {
    let a = 1000;
    let b = 44;
    let borrow = 1;
    let expected_diff = 955;
    let expected_new_borrow = 0;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    assert(diff == expected_diff);
    assert(new_borrow == expected_new_borrow);
}

#[test]
fn test_sub_limbs_with_borrow_case5() {
    let a = (constants::U64_POW_2_32 - 1) as u32;
    let b = (constants::U64_POW_2_32 - 1) as u32;
    let borrow = 1;
    let expected_diff = (constants::U64_POW_2_32 - 1) as u32;
    let expected_new_borrow = 1;
    let (diff, new_borrow) = sub_limbs_with_borrow(a, b, borrow);
    assert(diff == expected_diff);
    assert(new_borrow == expected_new_borrow);
}

// mul_limbs_with_carry
#[test]
fn test_mul_limbs_with_carry_case1() {
    let a = 75;
    let b = 9;
    let c = 11;
    let carry = 7;
    let expected_product = 181;
    let expected_new_carry = 0;
    let (product, new_carry) = mul_limbs_with_carry(a, b, c, carry);
    assert(product == expected_product);
    assert(new_carry == expected_new_carry);
}

#[test]
fn test_mul_limbs_with_carry_case2() {
    let a = 0;
    let b = 4294967295; // 2^32 - 1
    let c = 4294967295; // 2^32 - 1
    let carry = 0;
    let expected_product = 1;
    let expected_new_carry = 4294967294; // 2^32 - 2
    let (product, new_carry) = mul_limbs_with_carry(a, b, c, carry);
    assert(product == expected_product);
    assert(new_carry == expected_new_carry);
}

#[test]
fn test_mul_limbs_with_carry_case3() {
    let a = 0;
    let b = 4294967295; // 2^32 - 1
    let c = 4294967295; // 2^32 - 1
    let carry = 4294967295; // 2^32 - 1
    let expected_product = 0;
    let expected_new_carry = 4294967295; // 2^32 - 1
    let (product, new_carry) = mul_limbs_with_carry(a, b, c, carry);
    assert(product == expected_product);
    assert(new_carry == expected_new_carry);
}
