# herdr — terminal multiplexer / agent supervisor (herdr.dev).
#
# Replaces `curl -fsSL https://herdr.dev/install.sh | sh` in the agentbox image.
# That installer resolves herdr.dev/latest.json at run time and installs
# whatever it names, so two builds a day apart could silently differ.
#
# BUILT FROM SOURCE, not from the release binary. An earlier cut of this
# package pinned the published asset with upstream's own sha256, which proves
# the artifact did not change but says nothing about whether it matches this
# source. AGENTS.md is explicit: when the toolchain is packaged — and rust is —
# the package builds from the tarball. Same reasoning the rest of this bundle
# exists for.
#
# `needs` is set because cargo fetches crates during the build.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.9.1" in
{
  name = "herdr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/herdrdev/herdr/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "03403d3ef80dcf2b954dd5d27eb636e6c4f5279d240b48de272b7f53e4b73093",
      extract = true,
      strip_prefix = "herdr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    make,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    herdr = { glob = "usr/bin/herdr" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "herdrdev", repo = "herdr" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
