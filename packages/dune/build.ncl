let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "3.24.0" in
{
  name = "dune",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml/dune/releases/download/3.24.0/dune-3.24.0.tbz
      url = "gs://minimal-staging-archives/dune-%{version}.tbz",
      sha256 = "501f73727a939aa954dc0537e37792a1ba189e61719c81dc367e2594fe016034",
      # minimal's extractor doesn't know `.tbz`; unpack it in build.sh (tar -xf
      # autodetects bzip2), mirroring how ghc handles its source archive.
      extract = false,
    } | Source,
    base,
    ocaml,
    make,
    toolchain,
  ],
  # dune self-bootstraps from its own boot/ image using ocaml — fully offline.
  runtime_deps = [
    ocaml,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bin = { glob = "usr/bin/dune" } | OutputBin,
    # dune + dune-configurator findlib trees (META/.cmxa/.cmi). dune-configurator
    # is REQUIRED for the Jane Street stack's build-time `discover` executables —
    # `ocaml boot/bootstrap.ml` produces only the binary, so we build+install it
    # explicitly (see build.sh).
    libs = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml",
        repo = "dune",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/dune --version | grep -q '%{version}'"],
        ],
      } | Test,
    # The real proof dune works as a build tool: scaffold a tiny dune project,
    # build it (resolving the compiler via OCAMLPATH), and run the output.
    builds_a_project =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "mkdir -p proj && cd proj && printf '(lang dune 3.0)\\n' > dune-project && printf '(executable (name main))\\n' > dune && printf 'let () = print_string \"ok\"\\n' > main.ml && OCAMLPATH=/usr/lib/ocaml CAML_LD_LIBRARY_PATH=/usr/lib/ocaml/stublibs /usr/bin/dune build ./main.exe && ./_build/default/main.exe | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
