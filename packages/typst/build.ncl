let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let patch = import "../patch/build.ncl" in

let version = "0.15.1" in
{
  name = "typst",
  build_deps = [
    { file = "build.sh" } | Local,
    # Security backport of GHSA-rw6x-h3xm-cvq5 (low): `typst init` followed a
    # package manifest's `template.path` out of the package (`..` or an
    # absolute path), copying arbitrary readable directories into the new
    # project. Affected 0.11.0-0.15.1; fixed on main only by fdb38b89f1
    # ("Turn all manifest paths into virtual paths", typst#8989), and upstream
    # will not cut a patch release. Verbatim `git format-patch` of that commit
    # (applies to 0.15.1 with line offsets only). Drop on the next release.
    # Upstream notes symlinks inside a package can still lead out of it; that
    # is intended behaviour today (typst#5454) and not covered by this fix.
    { file = "GHSA-rw6x-h3xm-cvq5.patch" } | Local,
    patch,
    {
      url = "https://github.com/typst/typst/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "c07909e01a2a6941e52c9b616e48c209c755eed416d62bcf5583c37a4aca01a3",
      extract = true,
      strip_prefix = "typst-%{version}",
    } | Source,
    base,
    rust,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    # Verifies TLS against /etc/ssl/certs at runtime; see AGENTS.md "Trust store".
    ca-certificates,
    openssl,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    typst = { glob = "usr/bin/typst" } | OutputBin,
  },

  # GHSA-rw6x-h3xm-cvq5 regression tests, mirroring upstream's smoke tests.
  tests = {
    template_path_escape_refused =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "mkdir -p pkgs/local/evil/0.1.0 secret && echo stolen > secret/main.typ"],
          ["/bin/bash", "-c", "printf '[package]\\nname = \"evil\"\\nversion = \"0.1.0\"\\nentrypoint = \"lib.typ\"\\n\\n[template]\\npath = \"../../../../secret\"\\nentrypoint = \"main.typ\"\\n' > pkgs/local/evil/0.1.0/typst.toml"],
          # Unpatched, this copies ./secret into ./proj and succeeds.
          ["/bin/bash", "-c", "if typst init @local/evil:0.1.0 proj --package-path pkgs 2> err.txt; then echo 'typst init followed an escaping template.path' >&2; exit 1; fi"],
          ["/bin/bash", "-c", "grep -q 'path escapes root' err.txt"],
          ["/bin/bash", "-c", "test ! -e proj/main.typ"],
        ],
      } | Test,
    template_path_absolute_is_package_relative =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "mkdir -p pkgs/local/abs/0.1.0/template && echo Hello > pkgs/local/abs/0.1.0/template/main.typ"],
          ["/bin/bash", "-c", "printf '[package]\\nname = \"abs\"\\nversion = \"0.1.0\"\\nentrypoint = \"lib.typ\"\\n\\n[template]\\npath = \"/template\"\\nentrypoint = \"main.typ\"\\n' > pkgs/local/abs/0.1.0/typst.toml"],
          ["/bin/bash", "-c", "typst init @local/abs:0.1.0 proj --package-path pkgs"],
          ["/bin/bash", "-c", "grep -qx Hello proj/main.typ"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "typst",
        repo = "typst",
      },
    } | Attrs,
} | BuildSpec
