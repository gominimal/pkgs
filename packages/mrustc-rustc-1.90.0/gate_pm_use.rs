// gate_pm_use.rs: GATE-4b. Consumes the proc-macro dylib built from gate_pm.rs; compiling it
// requires the installed rustc to load and execute that dylib during expansion.
//
// Edition 2015 (no --edition is passed), so `#[macro_use] extern crate` brings the derive in.

#[macro_use]
extern crate gate_pm;

#[derive(GateVal)]
struct Target;

fn main() {
    let t = Target;
    // val() exists only because the proc macro ran; if expansion produced nothing this does
    // not compile.
    let v = t.val();
    if v != 13 {
        // The macro expanded but produced the wrong value; reported separately from a
        // plumbing failure.
        std::process::exit(121);
    }
    // 42 is computed from the macro-produced value, never a literal.
    let total = v * 3 + 3;
    std::process::exit(total as i32);
}
