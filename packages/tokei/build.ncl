# Auto-bootstrapped from https://github.com/XAMPPRocky/tokei by `pkgmgr bootstrap` (rust build).
# TODO: REVIEWER — verify outputs/runtime_deps + the build.sh.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "14.0.0" in
{
  name = "tokei",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/XAMPPRocky/tokei/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4e561dbb83ef1b46359714fc623fd45eddfb14821ece63a219470500fdd1cd26",
      extract = true,
      strip_prefix = "tokei-%{version}",
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
    tokei = { glob = "usr/bin/tokei" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "XAMPPRocky", repo = "tokei" },
      # TODO: REVIEWER — set license_spdx.
    } | Attrs,
} | BuildSpec
