let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "5.5.1" in
{
  name = "ocaml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml/ocaml/releases/download/5.5.1/ocaml-5.5.1.tar.gz
      url = "gs://minimal-staging-archives/ocaml-%{version}.tar.gz",
      sha256 = "ae47728d0a876665ccc7b745e3a8d8c9ca5ba63c4f7a11d4db6cdbd1dbeef4bb",
      extract = true,
      strip_prefix = "ocaml-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  # OCaml self-bootstraps from the tarball's own boot/ocamlc bytecode image, so
  # NO `needs { internet }` — the entire build is offline. The only inputs are a
  # C compiler + make (toolchain).
  #
  # runtime_deps: `ocamlopt` links every native binary by invoking the gcc
  # DRIVER (gcc -> cc1 -> collect2 -> ld), not ld directly — that driver lives
  # in gcc's `bins` + `libexec_bins`, NOT the `libgcc` subset (which is only
  # libgcc_s.so). So carry the full `toolchain` (binutils + gcc + glibc), not
  # `subsetOf gcc ["libgcc"]`.
  runtime_deps = [
    glibc,
    toolchain,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    # The stdlib tree: *.cma/.cmxa/.cmi/.cmx/.a plus stublibs *.so and the
    # `expunge`/`extract_crc` helper executables — hence allow_executable.
    stublibs = { glob = "usr/lib/ocaml/stublibs/*.so*" } | OutputLib,
    stdlib = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # VERIFY -only vs -or-later against the tarball LICENSE (importer F1 guard).
      license_spdx = "LGPL-2.1-only WITH OCaml-LGPL-linking-exception",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml",
        repo = "ocaml",
      },
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/ocaml -version | grep -q '%{version}'"],
        ],
      } | Test,
    # The real proof the toolchain is whole: bytecode AND native compilation of
    # a trivial program, exercising ocamlc, ocamlopt, and the gcc driver
    # ocamlopt shells out to.
    compile_bytecode_and_native =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = print_string \"ok\"' > t.ml && /usr/bin/ocamlc t.ml -o tb && ./tb | grep -q ok"],
          ["/bin/bash", "-c", "echo 'let () = print_string \"ok\"' > t.ml && /usr/bin/ocamlopt t.ml -o tn && ./tn | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
