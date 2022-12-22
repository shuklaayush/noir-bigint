global U32_POW_2_0 : u32 = 1;
global U32_POW_2_1 : u32 = 2;
global U32_POW_2_3 : u32 = 8;
global U32_POW_2_6 : u32 = 32;
global U32_POW_2_7 : u32 = 128;
global U32_POW_2_8 : u32 = 256;
global U32_POW_2_14 : u32 = 16384;
global U32_POW_2_16 : u32 = 65536;
global U32_POW_2_24 : u32 = 16777216;
global U32_MAX : u32 = 4294967295;

fn shift_left_8(x : u32) -> u32 {
    x * U32_POW_2_8
}

fn shift_left_16(x : u32) -> u32 {
    x * U32_POW_2_16
}

fn shift_left_24(x : u32) -> u32 {
    x * U32_POW_2_24
}