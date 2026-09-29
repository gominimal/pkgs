// gate_pm.rs — GATE-4a.  Compiled with `--crate-type=proc-macro`, so the installed rustc must
// produce a host dylib that gate_pm_use.rs then loads and executes at compile time.
// Readable copy of the body build.sh embeds as a heredoc; keep the two in sync.

extern crate proc_macro;

use proc_macro::TokenStream;

#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // 13 is produced inside the dylib that rustc loaded and ran, and is checked by the consumer.
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
