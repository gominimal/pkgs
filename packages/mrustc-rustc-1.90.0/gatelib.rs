// gatelib.rs: GATE-2's crate, compiled with `--crate-type=rlib`. Emitting an rlib runs
// ArArchiveBuilder::build_inner, the code path archive-zerolen-skip.sh patches. gate190.rs
// consumes it across the crate boundary, so the archive is also read back and vtable layout
// survives the boundary.

pub trait Shape {
    fn area(&self) -> i64;
}

pub struct Sq(pub i64);

impl Shape for Sq {
    fn area(&self) -> i64 {
        self.0 * self.0
    }
}

/// Rolling checksum with wrapping arithmetic: a computed value with defined overflow behaviour.
pub fn checksum(v: &[i64]) -> i64 {
    let mut acc: i64 = 7;
    for x in v {
        acc = acc.wrapping_mul(31).wrapping_add(*x);
    }
    acc
}
