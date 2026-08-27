// gatelib.rs — GATE-2's crate.  Compiled with `--crate-type=rlib`.
//
// AUDIT COPY.  build.sh embeds this body inline (a heredoc) so the recipe is self-contained; this
// file is the human-readable source of truth.  Version-agnostic edition-2015 Rust — identical
// across every rung; ported verbatim from packages/mrustc-rustc-1.90.0/gatelib.rs.
//
// Its FIRST purpose is not its contents: emitting an rlib forces the archive builder to run — the
// exact code path that failed on a zero-length member in the mrustc rung.  A single-binary gate
// never touches it.  Its SECOND purpose is to be consumed by gatestd.rs ACROSS a crate boundary,
// which proves the archive was not merely written but read back — and, via the trait object, that
// vtable layout survives that boundary.

pub trait Shape {
    fn area(&self) -> i64;
}

pub struct Sq(pub i64);

impl Shape for Sq {
    fn area(&self) -> i64 {
        self.0 * self.0
    }
}

/// A cheap rolling checksum. Deliberately uses wrapping arithmetic so its result is a
/// computed value with defined overflow behaviour rather than a constant.
pub fn checksum(v: &[i64]) -> i64 {
    let mut acc: i64 = 7;
    for x in v {
        acc = acc.wrapping_mul(31).wrapping_add(*x);
    }
    acc
}
