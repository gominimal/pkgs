// gate_pm_use.rs — GATE-4b.  Consumes the proc-macro dylib built by gate_pm.rs.
//
// Compiling this file requires the installed rustc to LOAD and EXECUTE gate_pm's dylib during
// expansion.  Running the result proves the expansion produced correct code.
//
// Edition 2015 (no --edition is passed), so `#[macro_use] extern crate` is how the derive
// comes into scope.

#[macro_use]
extern crate gate_pm;

#[derive(GateVal)]
struct Target;

fn main() {
    let t = Target;
    // val() exists ONLY because the proc macro ran. If expansion silently produced nothing,
    // this file does not compile — which GATE-4 reports as a distinct failure.
    let v = t.val();
    if v != 13 {
        // The macro expanded, but produced the wrong value: a codegen/expansion miscompile
        // rather than a plumbing failure. Named separately so the log says which.
        std::process::exit(121);
    }
    // 42 is never a literal in the success path: it is computed from the macro-produced value.
    let total = v * 3 + 3;
    std::process::exit(total as i32);
}
