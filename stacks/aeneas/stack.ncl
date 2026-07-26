let { stack, .. } = import "minimal.ncl" in
# The aeneas verification loadout: everything to take Rust all the way to a
# machine-checked functional model in one minimal session —
#
#   charon rustc foo.rs        # Rust -> foo.llbc  (the charon frontend)
#   aeneas -backend lean foo.llbc   # .llbc -> Foo.lean  (the translation)
#   lean Foo.lean              # Lean 4 CHECKS the model
#
# It folds in the `ocaml` and `rust` stacks' setup (aeneas is written in OCaml;
# charon is a rustc_private Rust tool) plus Lean 4 to actually verify the models
# aeneas emits — so the session is a complete Rust-verification bench, not just a
# model emitter. Opt-in (no `matches_project_if_any`): a Rust project should get
# the plain `rust` stack by default; you ask for this one explicitly.
stack {
  name = "aeneas",

  build_packages = [
    # Shared build base (from the ocaml + rust stacks).
    "gcc",
    "binutils",
    "pkgconf",
    "linux_headers",

    # OCaml dev stack — aeneas is OCaml, and this also lets you build/hack OCaml
    # in the session (dune + findlib resolve from the merged /usr tree offline).
    "ocaml",
    "dune",
    "ocamlfind",

    # THE Rust toolchain: the pinned nightly with rustc-dev that charon's
    # `rustc_private` driver links. It's a full toolchain (rustc + cargo +
    # rust-std), so it serves BOTH charon AND general Rust work — deliberately
    # NOT the stable `rust` package, which would put a second rustc on PATH that
    # charon's `rustc --print sysroot` could resolve to (the wrong sysroot, no
    # librustc_driver).
    "rust-nightly-charon",

    # The aeneas toolchain: the OCaml translator + the charon Rust frontend
    # (ships both `charon` and `charon-driver`; charon spawns the driver off PATH).
    "aeneas",
    "charon",

    # Lean 4 — the prover for the models aeneas emits, so the loop actually
    # closes (emit AND check), not just emit `.lean` source.
    "lean",
  ],

  build_env_vars = {
    CC = "gcc",

    # OCaml offline library resolution (from the ocaml stack).
    OCAMLPATH = "/usr/lib/ocaml",
    CAML_LD_LIBRARY_PATH = "/usr/lib/ocaml/stublibs",

    # Rust linker via gcc (from the rust stack).
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "gcc",
    CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER = "gcc",

    # The load-bearing one: charon runs in "toolchain in PATH" mode because there
    # is no rustup in minimal. Without this, charon panics "Can't find rustup"
    # (src/bin/charon/main.rs:269). rustc is on PATH via rust-nightly-charon;
    # charon shells `rustc --print sysroot` at runtime to locate librustc_driver.
    CHARON_TOOLCHAIN_IS_IN_PATH = "1",
  },

  # aeneas is a verification tool, not a project builder — there's no canonical
  # "build this directory". Default to surfacing the toolchain; real use is the
  # charon -> aeneas -> lean pipeline above, run by hand on a target crate.
  build_cmd = "aeneas --help",
}
