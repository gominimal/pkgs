let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "3.20.2" in
{
  name = "dune",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml/dune/releases/download/3.20.2/dune-3.20.2.tbz
      url = "gs://minimal-staging-archives/dune-%{version}.tbz",
      sha256 = "b1a86b2d60bdb4a8b9bb6861bdf2f9f28a6e7cb5d833ce81afecceb9ef9ca549",
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
          ["/bin/bash", "-c", "/usr/bin/dune --version | grep -q '3.20.2'"],
        ],
      } | Test,
  },
} | BuildSpec
