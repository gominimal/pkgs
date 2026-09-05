// gate_pm.rs — GATE-4a.  Compiled with `--crate-type=proc-macro`, which forces the installed
// rustc to produce a HOST DYLIB and, in gate_pm_use.rs, to dlopen and execute it at compile time.
//
// AUDIT COPY.  build.sh embeds this body inline (a heredoc); this file is the source of truth.
//
// This is the highest-value gate in the recipe for a CHAIN rung.  The NEXT rung's x.py is driven
// entirely by cargo and rustc's own source is saturated with #[derive].  A rustc that cannot
// dlopen a proc-macro .so passes every statically-linked gate and then fails ~hours into rung 3,
// where it gets misdiagnosed as an x.py problem.

extern crate proc_macro;

use proc_macro::TokenStream;

#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // The value 13 is produced HERE, inside a dylib that rustc loaded and ran, and is checked by
    // the consumer.  It cannot appear by accident in a statically-linked build.
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
