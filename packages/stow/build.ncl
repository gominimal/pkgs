# Imported from Wolfi `stow` by `pkgmgr import-wolfi` (autotools build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let perl = import "../perl/build.ncl" in
let version = "2.4.1" in
{
  name = "stow",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    autoconf,
    automake,
    libtool,
    m4,
    make,
    pkgconf,
    toolchain,
    glibc,
    perl,
    {
      url = "gs://minimal-staging-archives/stow-%{version}.tar.gz",
      sha256 = "2a671e75fc207303bfe86a9a7223169c7669df0a8108ebdf1a7fe8cd2b88780b",
      extract = true,
      strip_prefix = "stow-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [perl],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GnuProject, name = "stow" },
      license_spdx = "GPL-3.0",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "stow --version\nstow --help\n\nmkdir test links\ncd test || exit\necho 'this is a test' > test.file\n\nstow -S -t ../links .\nls -1 ../links/test.file"],
        ],
      } | Test,
  },
} | BuildSpec
