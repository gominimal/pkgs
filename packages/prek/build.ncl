let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let git = import "../git/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "0.5.7" in
{
  name = "prek",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/j178/prek/v%{version}.tar.gz",
      sha256 = "c14bfbb5121c24421aea5fbb91a9c835e3e3372e53bdaeb3dedd87cc8eda56b5",
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
  ],

  cmd = "./build.sh",

  outputs = {
    prek = { glob = "usr/bin/prek" } | OutputLib,
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
    # prek builds its HTTP client on first use (a toolchain download) and logs
    # which roots it chose. A local hook asking for a deno that cannot exist
    # makes prek fetch deno's version list; with no network the fetch fails,
    # but the client, and its log line, come first. PREK_NATIVE_TLS=0 must
    # still select the compiled-in roots.
    system_ca_default =
      {
        class = 'Standalone,
        test_deps = [base, git, ca-certificates],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              unset PREK_NATIVE_TLS
              test -s /etc/ssl/certs/ca-certificates.crt
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
