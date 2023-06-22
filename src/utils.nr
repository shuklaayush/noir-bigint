// Compute a + b + carry, returning the result and the new carry over.
// TODO: Does carry need to be a u63?
fn adc(a: u63, b: u63, carry: u63) -> (u63, u63) {
    let ret = a as Field + b as Field + carry as Field;
    (ret as u63, (ret as u65 >> 63) as u63)
}

// Compute a - (b + borrow), returning the result and the new borrow.
fn sbb(a: u63, b: u63, borrow: u63) -> (u63, u63) {
    // NOTE: Relies on overflow
    let ret = a as u65 - (b as u65 + (borrow >> 62) as u65);
    (ret as u63, (ret >> 2) as u63)
}

// Compute a + (b * c) + carry, returning the result and the new carry over.
fn mac(a: u63, b: u63, c: u63, carry: u63) -> (u63, u63) {
    let ret = (a as Field) + ((b as Field) * (c as Field)) + (carry as Field);
    // TODO: This shift right at double width is forcing to use <= 126/2 bit limbs
    (ret as u63, (ret as u126 >> 63) as u63)
}
