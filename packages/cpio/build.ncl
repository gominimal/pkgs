let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.15" in
{
  name = "cpio",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/cpio/cpio-%{version}.tar.gz",
      sha256 = "efa50ef983137eefc0a02fdb51509d624b5e3295c980aa127ceee4183455499e",
      extract = true,
      strip_prefix = "cpio-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [glibc],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cpio = { glob = "usr/bin/cpio" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "cpio",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/cpio --version",
  },
} | BuildSpec
