use dep::std;
mod u32_utils;
mod arithmetic;

global NUM_LIMBS : Field = 8;
global LIMB_BITS : Field = 32;
global LIMB_BYTES : Field = 4;

// helper function

// This defines a BigInt, a smart wrapper around a sequence of u32 limbs, least-significant limb first
struct BigInt {
    limbs : [u32; NUM_LIMBS]
}

impl BigInt {
    fn new(limbs : [u32; NUM_LIMBS]) -> Self {
        Self {
            limbs: limbs
        }
    }

    fn zero() -> Self {
        BigInt::new([0 as u32; NUM_LIMBS])
    }

    fn one() -> Self {
        let mut one = [0 as u32; NUM_LIMBS];
        one[0] = 1;
        BigInt::new(one)
    }
    
    fn is_even(self : Self) -> bool {
        self.limbs[0] % 2 == 0
    }

    fn is_odd(self : Self) -> bool {
        self.limbs[0] % 2 == 1
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

        let bytes_len = std::array::len(bytes);
        
        // TODO: Should we allow this?
        constrain bytes_len <= MAX_BYTES;

        let mut limbs = [0 as u32; NUM_LIMBS];
        let mut limb : u32 = 0;
        for i in 0..MAX_BYTES {
            let limb_index = ((i as u8) / 4) as Field;
            // i modulo 4
            let byte_significance = i - (limb_index * 4);

            if i < bytes_len {
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
    
    // Arithmetic

    

}

fn main(x : Field, y : pub Field) {
    constrain x != y;
    run_tests();
    arithmetic::run_tests();
}

// Tests
fn run_tests() {
    test_from_bytes_be();
}

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