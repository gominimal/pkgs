let { stack, .. } = import "minimal.ncl" in
stack {
  name = "ocaml",

  # The offline OCaml dev toolchain: the compiler + build tool + findlib
  # resolver, plus the gcc driver `ocamlopt` shells out to for native codegen
  # (gcc -> cc1 -> collect2 -> ld) and pkgconf for C-stub libraries (zarith).
  build_packages = ["gcc", "ocaml", "dune", "ocamlfind", "binutils", "pkgconf", "linux_headers"],

  build_env_vars = {
    CC = "gcc",
    # Dune + findlib resolve library dependencies from the merged /usr tree via
    # OCAMLPATH — the same offline convention every OCaml package build uses (no
    # opam, no network). No env_state_wiring / download cache: the pure-dune
    # model has nothing to persist (cf. rust's CARGO_HOME).
    OCAMLPATH = "/usr/lib/ocaml",
    CAML_LD_LIBRARY_PATH = "/usr/lib/ocaml/stublibs",
  },

  build_cmd = "dune build",

  # A `dune-project` at the root is the reliable marker of a dune project
  # (every one has it); `*.opam` files sit alongside but dune-project is
  # canonical.
  matches_project_if_any = [
    {
      file_regexes = {
        "dune-project" = "*",
      },
    }
  ],
}
