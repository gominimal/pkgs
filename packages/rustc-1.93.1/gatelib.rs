// gatelib.rs — GATE-2's crate, compiled with `--crate-type=rlib`.
// Readable copy of the body build.sh embeds as a heredoc; keep the two in sync.  Edition-2015
// Rust, identical across every rung.
// Emitting an rlib exercises the archive builder, which a single-binary gate never touches.
// gatestd.rs then consumes it across a crate boundary, proving the archive is read back and that
// vtable layout survives the boundary.

pub trait Shape {
    fn area(&self) -> i64;
}

pub struct Sq(pub i64);

impl Shape for Sq {
    fn area(&self) -> i64 {
        self.0 * self.0
    }
}

/// A cheap rolling checksum with wrapping arithmetic, so the result is a computed value with
/// defined overflow behaviour rather than a constant.
pub fn checksum(v: &[i64]) -> i64 {
    let mut acc: i64 = 7;
    for x in v {
        acc = acc.wrapping_mul(31).wrapping_add(*x);
    }
    acc
}
