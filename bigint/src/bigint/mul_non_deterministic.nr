global NUM_LIMBS : Field = 8;
global PRODUCT_MODULI_LENGTH : Field = 15;
global NUM_MODULI : Field = 4;

// Given x ∈ [b]^n , partially_reduced_sum < nmb
fn partially_reduced_sum(base : Field, m : Field, limbs : [Field; NUM_LIMBS]) -> Field{
    let mut result = limbs[0];
    let mut base_modulo_m = 1;
    for i in 1..NUM_LIMBS {
        // iteratively calculate b^i % m
        base_modulo_m = (base * base) % m;
        result = result + (base_modulo_m * limbs[i]);
    };
    result
}

// Given x ∈ [b]^n , partially_reduced_sum < nmb
fn partially_reduced_product(base : Field, m : Field, limbs1 : [Field; NUM_LIMBS], limbs2 : [Field; NUM_LIMBS]) -> Field{
    let mut result = limbs[0];
    let mut base_modulo_m = [1; PRODUCT_MODULI_LENGTH];
    // iteratively calculate b^(i + j) % m
    for i in 1..PRODUCT_MODULI_LENGTH {
        base_modulo_m[i] = (base_modulo_m[i - 1] * base) % m
    };
    for i in 1..NUM_LIMBS {
        for j in 1..NUM_LIMBS {
            result = result + (base_modulo_m[i + j] * limbs[i]);
        }
    };
    result
}


fn test_partially_reduced_sum_case1() {
[ 21888242871839275222246405745257275088548364400416034343698204186575808495617, 49979693, 49979737, 49979767 ]
[
  [ 1, 4294967296, 18446744073709551616, 79228162514264337593543950336, 340282366920938463463374607431768211456, 1461501637330902918203684832716283019655932542976, 6277101735386680763835789423207666416102355444464034512896, 26959946667150639794667015087019630673637144422540572481103610249216 ],
  [ 1, 46693391, 18832685, 13440723, 28507799, 48329333, 34982825, 11730231 ],
  [ 1, 46689651, 4468199, 30967381, 46500792, 18729689, 29251948,  6797305 ],
  [ 1, 46687101, 38329916, 46938169, 20608808,  8091908, 13542137, 14940410 ]
]

}
