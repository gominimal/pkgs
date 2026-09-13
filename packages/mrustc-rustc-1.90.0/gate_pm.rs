// gate_pm.rs — GATE-4a.  Compiled with `--crate-type=proc-macro`, which forces the installed
// rustc to produce a HOST DYLIB and, in gate_pm_use.rs, to dlopen and execute it at compile
// time.
//
// This is the highest-value gate in the recipe.  run_rustc/Makefile:218
// (`cp $(LIBDIR_2)*.$(DYLIB_EXT) $(PREFIX)lib`) is the only thing producing dylib std.  If it
// silently produced nothing, or if `proc_macro` never landed in LIBDIR, or if rustc cannot
// dlopen a proc-macro .so, then every statically-linked gate STILL PASSES and the failure
// surfaces ~20h into rung 2 — where it gets misdiagnosed as an x.py problem, because rustc's
// own bootstrap is saturated with derives.

extern crate proc_macro;

use proc_macro::TokenStream;

#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // The value 13 is produced HERE, inside a dylib that rustc loaded and ran, and is checked
    // by the consumer.  It cannot appear by accident in a statically-linked build.
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
