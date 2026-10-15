// gate_pm.rs: GATE-4a. Compiled with `--crate-type=proc-macro`, so the installed rustc must
// produce a host dylib that gate_pm_use.rs then dlopens and executes at compile time. This
// checks dylib std (run_rustc/Makefile:218) and proc_macro loading, which statically linked
// gates never exercise.

extern crate proc_macro;

use proc_macro::TokenStream;

#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // The value 13 is produced inside the dylib rustc loaded and ran; the consumer checks it.
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
