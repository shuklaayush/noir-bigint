use dep::std::println;

use crate::ecdsa_secp256k1::fp::PrimeField as Fp;
use crate::ecdsa_secp256k1::fq::PrimeField as Fq;

// Point in three-dimensional Jacobian coordinates
struct Point {
    x: Fp,
    y: Fp,
    z: Fp // z = 0 corresponds to point at infinity.
}

// Curve specification
struct Curve { // Short Weierstrass curve
    // Coefficients in defining equation y^2 = x^3 + axz^4 + bz^6
    a: Fp,
    b: Fp,
    // Generator as point in projective coordinates
    gen: Point
}

impl Point {
    fn from_affine(x: Fp, y: Fp) -> Self {
        Self {x, y, z: Fp::one()}
    }

    // Additive identity
    fn zero() -> Self {
        Self {x: Fp::zero(), y: Fp::zero(), z: Fp::zero()}
    }

    // Check for equality
    fn eq(self, p: Point) -> bool {
        let Self {x: x1, y: y1, z: z1} = self;
        let Self {x: x2, y: y2, z: z2} = p;

        let z1_is_zero = z1.is_zero();
        let z2_is_zero = z2.is_zero();

        if (!z1_is_zero & !z2_is_zero) {
            let z1sq = z1.square();
            let z2sq = z2.square();
            
            let z1cb = z1sq.mul(z1);
            let z2cb = z2sq.mul(z2);

            (x1.mul(z2sq).eq(x2.mul(z1sq))) & (y1.mul(z2cb).eq(y2.mul(z1cb)))
        } else {
            z1_is_zero & z2_is_zero

        }
    }

    // Check if zero
    fn is_zero(self) -> bool {
        let Self {x: _x, y: _y, z} = self;

        z.is_zero()
    }

    // Negation
    fn negate(self) -> Self {
        let Self {x, y, z} = self;

        Self { x, y: y.neg(), z }
    }

    // Convert to affine coordinates
    // TODO: Create affine struct
    fn to_affine(self) -> (Fp, Fp) {
        assert(!self.z.is_zero());

        let zinv = self.z.invert();
        let zinv2 = zinv.square();

        let x = self.x.mul(zinv2);
        let y = self.y.mul(zinv2).mul(zinv);

        (x, y)
    }

    // Print as bytes
    fn println(self: Self) {
        self.x.println();
        self.y.println();
        self.z.println();
    }

    // Print as bytes
    fn println_affine(self: Self) {
        if (self.z.is_zero()) {
            println("O");
            println("O");
        } else {
            let (x, y) = self.to_affine();
            
            x.println();
            y.println();
        }
    }
}


impl Curve {
    // Curve constructor
    fn new(a: Fp, b: Fp, gen: Point) -> Curve {
        // Check curve coefficients
        assert(!(Fp::from_u56(4).mul(a.square().mul(a)).add(Fp::from_u56(27).mul(b.square()))).is_zero());

        let curve = Curve { a, b, gen };

        // gen should be on the curve
        assert(curve.contains(gen));

        curve
    }

    // Membership check
    fn contains(self, p: Point) -> bool {
        let Point {x, y, z} = p;
        
        let xx = x.square();
        let zz = z.square();
        let zzzz = zz.square();

        let lhs = y.square();
        let mut rhs = xx.mul(x).add(self.a.mul(x).mul(zzzz));
        rhs = rhs.add(self.b.mul(zzzz.mul(zz)));
        
        lhs.eq(rhs)
    }

    // Point addition
    fn add(self, p1: Point, p2: Point) -> Point {
        if p1.is_zero() {
            p2
        } else if p2.is_zero() {
            p1
        } else {
            let Point {x: x1, y: y1, z: z1} = p1;
            let Point {x: x2, y: y2, z: z2} = p2;
            
            let z1z1 = z1.square();
            let z2z2 = z2.square();
            
            let you1 = x1.mul(z2z2);
            let you2 = x2.mul(z1z1);
            
            let s1 = y1.mul(z2z2.mul(z2));
            let s2 = y2.mul(z1z1.mul(z1));
            
            if you1.eq(you2) {
                if !s1.eq(s2) {
                    Point::zero()
                } else {
                    self.double(p1)
                }
            } else {
                let h = you2.sub(you1);
                let r = s2.sub(s1);

                let hh = h.square();
                let hhh = hh.mul(h);
                // BUG: Doesn't work in a single line
                let mut x3 = r.square().sub(hhh);
                x3 = x3.sub(you1.mul(hh).double());
                // BUG: Doesn't work in a single line
                let mut y3 = r.mul(you1.mul(hh).sub(x3));
                y3 = y3.sub(s1.mul(hhh));
                let z3 = h.mul(z1).mul(z2);
                
                Point { x: x3, y: y3, z: z3 }
            }
        }
    }

    // Point subtraction
    fn sub(self, p1: Point, p2: Point) -> Point {
        self.add(p1, p2.negate())
    }

    // Point doubling
    fn double(self, p: Point) -> Point {
        let Point {x, y, z} = p;
        
        if p.is_zero() {
            p
        } else if y.is_zero() {
            Point::zero()
        } else {
            let xx = x.square();
            let yy = y.square();
            let yyyy = yy.square();
            
            let zzzz = z.square().square();

            let s = Fp::from_u56(4).mul(x.mul(yy));
            let m = Fp::from_u56(3).mul(xx).add(self.a.mul(zzzz));

            let x0 = m.square().sub(s.double());
            let y0 = m.mul(s.sub(x0)).sub(Fp::from_u56(8).mul(yyyy));
            let z0 = y.mul(z).double();

            Point{ x: x0, y: y0, z: z0 }
        }
    }

    // Scalar multiplication with scalar represented by a bit array (little-endian convention).
    // If k is the natural number represented by `bits`, then this computes p + ... + p k times.
    fn bit_mul<N>(self, bits: [u1; N], p: Point) -> Point {
        let mut out = Point::zero();
        
        for i in 0..N {
            // TODO: Only start at first non-zero bit
            out = self.double(out);
            if(bits[N - i - 1] == 1) {
                out = self.add(out, p);
            }
            // BUG: This breaks
            // out = self.add(
            //     self.add(out, out),
            //     if(bits[N - i - 1] == 0) {Point::zero()} else {p});
        }

        out
    }
    
    // Scalar multiplication (p + ... + p n times)
    fn mul(self, n: Fq, p: Point) -> Point {
        let n_as_bits = n.to_bits();
        self.bit_mul(n_as_bits, p)
    }
}
