use dep::std::println;

use crate::examples::ed25519::fp::PrimeField as Fp;
use crate::examples::ed25519::fq::PrimeField as Fq;

// Point in extended twisted Edwards coordinates
struct Point {
    x: Fp,
    y: Fp,
    t: Fp,
    z: Fp
}

// Curve specification
struct Curve { // Twisted Edwards curve
    // Coefficients in defining equation a(x^2 + y^2)z^2 = z^4 + dx^2y^2
    a: Fp,
    d: Fp,
    // Generator as point in projective coordinates
    gen: Point
}

impl Point {
    fn from_affine(x: Fp, y: Fp) -> Self {
        Self {x, y, t: x.mul(y), z: Fp::one()}
    }

    // Additive identity
    fn zero() -> Self {
        Self { x: Fp::zero(), y: Fp::one(), t: Fp::zero(), z: Fp::one() }
    }

    // Check for equality
    fn eq(self, p: Point) -> bool {
        let Self {x: x1, y: y1, t: _t1, z: z1} = self;
        let Self {x: x2, y: y2, t: _t2, z:z2} = p;

        x1.mul(z2).eq(x2.mul(z1)) & y1.mul(z2).eq(y2.mul(z1))
    }

    // Check if zero
    fn is_zero(self) -> bool {
        let Self {x, y, t: _t, z} = self;

        x.is_zero() & y.eq(z)
    }

    // Negation
    fn negate(self) -> Self {
        let Self {x, y, t, z} = self;

        Self { x: x.neg(), y, t: t.neg(), z }
    }
    
    // Convert to affine coordinates
    // TODO: Create struct
    fn to_affine(self) -> (Fp, Fp) {
        let zinv = self.z.invert();

        let x = self.x.mul(zinv);
        let y = self.y.mul(zinv);
        
        (x, y)
    }

    // Print as bytes
    fn println(self: Self) {
        self.x.println();
        self.y.println();
        self.t.println();
        self.z.println();
    }

    // Print as bytes
    fn println_affine(self: Self) {
        let (x, y) = self.to_affine();
        
        x.println();
        y.println();
    }
}


impl Curve {
    // Curve constructor
    fn new(a: Fp, d: Fp, gen: Point) -> Curve {
        // Check curve coefficients
        assert(!a.is_zero());
        assert(!d.is_zero());
        assert(!a.eq(d));
        
        let curve = Curve { a, d, gen };

        // gen should be on the curve
        assert(curve.contains(gen));

        curve
    }

    // Membership check
    fn contains(self, p: Point) -> bool {
        let Point {x, y, t, z} = p;

        if z.is_zero() | !z.mul(t).eq(x.mul(y)) {
            false
        } else {
            let zz = z.square();
            let xx = x.square();
            let yy = y.square();

            zz.mul(self.a.mul(xx).add(yy)).eq(zz.square().add(self.d.mul(xx).mul(yy)))
        }
    }

    // Point addition
    fn add(self, p1: Point, p2: Point) -> Point {
        let Point{x: x1, y: y1, t: t1, z: z1} = p1;
        let Point{x: x2, y: y2, t: t2, z: z2} = p2;

        let a = x1.mul(x2);
        let b = y1.mul(y2);
        let c = self.d.mul(t1).mul(t2);
        let d = z1.mul(z2);
        // BUG: This gives incorrect result
        // let mut e = x1.add(y1).mul(x2.add(y2)).sub(a).sub(b);
        let mut e = x1.add(y1).mul(x2.add(y2)).sub(a);
        e = e.sub(b);
        let f = d.sub(c);
        let g = d.add(c);
        let h = b.sub(self.a.mul(a));

        let x = e.mul(f);
        let y = g.mul(h);
        let t = e.mul(h);
        let z = f.mul(g);

        Point { x, y, t, z }
    }

    // Point subtraction
    fn sub(self, p1: Point, p2: Point) -> Point {
        self.add(p1, p2.negate())
    }

    // Point doubling
    fn double(self, p: Point) -> Point {
        let Point{x: x1, y: y1, t: _t1, z: z1} = p;

        let a = x1.square();
        let b = y1.square();
        let c = z1.square().double();
        let d = self.a.mul(a);
        // BUG: This breaks in a single line
        // let e = (x1.add(y1)).square().sub(a).sub(b);
        let mut e = (x1.add(y1)).square().sub(a);
        e = e.sub(b);
        let g = d.add(b);
        let f = g.sub(c);
        let h = d.sub(b);

        let x = e.mul(f);
        let y = g.mul(h);
        let t = e.mul(h);
        let z = f.mul(g);
        
        Point { x, y, t, z }
    }

    // Scalar multiplication with scalar represented by a bit array (little-endian convention).
    // If k is the natural number represented by `bits`, then this computes p + ... + p k times.
    fn bit_mul<N>(self, bits: [u1; N], p: Point) -> Point {
        let mut out = Point::zero();
        
        for i in 0..N {
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

// TODO:
// 1. Remove redundant operations from formulas
