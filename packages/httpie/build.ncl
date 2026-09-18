let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in

# HTTPie — the human-friendly HTTP client the agentbox image installs via dnf.
#
# Packaged the same way as diffoscope: `pip3 install` into $OUTPUT_DIR and ship
# the resulting site-packages, rather than packaging the dependency closure by
# hand. httpie pulls in requests, rich, pygments, multidict, defusedxml,
# requests-toolbelt and their transitive deps — 12 distributions — and every one
# of them is pure Python with no reason to exist as a separate pkgs entry.
#
# (We do also ship `xh`, a Rust HTTPie-alike. It is a good substitute for the
# common cases but not a drop-in: different flag surface, no sessions, no
# plugins. Both can coexist.)
#
# `needs` is set because pip resolves the dependency tree from PyPI at build
# time. That is the trade for not vendoring 12 packages: the build reaches the
# network, and the lockfile is upstream's own metadata rather than ours.
let version = "3.2.4" in

{
  name = "httpie",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/httpie/httpie/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b185cd8d81325f97c773582e50f1c5e047c2d8575b53d676469c9daf2a52f341",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    toolchain,
    uv,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/http*" } | OutputBin,
    site_packages = { glob = "usr/lib/python*/site-packages/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "httpie",
        repo = "cli",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/http --version | grep -q 3.2.4"],
          # Exercise an actual import path, not just --version: httpie's
          # entrypoint pulls in requests/rich/pygments, so a missing dependency
          # surfaces here rather than at first real use.
          ["/bin/bash", "-c", "/bin/http --help >/dev/null"],
        ],
      } | Test,
  },
} | BuildSpec
