let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let git = import "../git/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "0.5.10" in
{
  name = "prek",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/j178/prek/v%{version}.tar.gz",
      sha256 = "596e702c00a25a19dc25d7734ba56922ed6857252fc474a787fe271d0d42d4ec",
      extract = true,
      strip_prefix = "prek-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    # The patched default reads /etc/ssl/certs/ca-certificates.crt; without the
    # store in the closure it silently falls back to the compiled-in roots.
    ca-certificates,
  ],

  cmd = "./build.sh",

  outputs = {
    prek = { glob = "usr/bin/prek" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "j178",
        repo = "prek",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    # The store must come from prek's own runtime_deps edge. A test closure
    # without any needs.internet package proves that: [bash-bootstrap] plus prek's runtime
    # closure has none, so ca-certificates can only arrive through that edge
    # (AGENTS.md "Trust store", item 2). This one fails if the edge is dropped.
    store_from_runtime_deps =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              test -s /etc/ssl/certs/ca-certificates.crt
              prek --version
            "%
          ],
        ],
      } | Test,
    # prek builds its HTTP client on first use (a toolchain download) and logs
    # which roots it chose. A local hook asking for a deno that cannot exist
    # makes prek fetch deno's version list; the client, and its log line, come
    # before the fetch, so the check holds whether or not the fetch succeeds.
    # PREK_NATIVE_TLS=0 must still select the compiled-in roots. prek shells
    # out to git, so git is a test dep; git brings curl, which declares
    # needs.internet, so this closure gets ca-certificates (and host network)
    # injected regardless of prek's edge. It does not test the store; the test
    # above does.
    system_ca_default =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, git, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              unset PREK_NATIVE_TLS
              export PREK_HOME="$(mktemp -d)"
              cd "$(mktemp -d)"
              git init -q .
              printf '%s\n' 'repos:' '  - repo: local' '    hooks:' '      - id: t' '        name: t' '        entry: deno --version' '        language: deno' '        language_version: "99.99.99"' '        always_run: true' '        pass_filenames: false' > .pre-commit-config.yaml
              git add .pre-commit-config.yaml
              RUST_LOG=prek=debug prek run --all-files > out 2>&1 || true
              grep -q 'Using native TLS for reqwest client' out || { cat out; exit 1; }
              PREK_NATIVE_TLS=0 RUST_LOG=prek=debug prek run --all-files > out0 2>&1 || true
              grep -q 'deno.com/versions.json\|remote versions\|Failed' out0 || { cat out0; exit 1; }
              ! grep -q 'Using native TLS for reqwest client' out0
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
