// gate_pm_use.rs — GATE-4b.  Consumes the proc-macro dylib built from gate_pm.rs: compiling it
// makes the installed rustc load and execute that dylib; running it checks the expansion.
// Readable copy of the body build.sh embeds as a heredoc; keep the two in sync.
// Edition 2015 (no --edition is passed), so `#[macro_use] extern crate` brings the derive in.

#[macro_use]
extern crate gate_pm;

#[derive(GateVal)]
struct Target;

fn main() {
    let t = Target;
    // val() exists only because the proc macro ran; without expansion this file does not compile.
    let v = t.val();
    if v != 13 {
        // expanded, but to the wrong value: reported separately from a load failure
        std::process::exit(121);
    }
    // 42 is computed from the macro-produced value, never a literal.
    let total = v * 3 + 3;
    std::process::exit(total as i32);
}
