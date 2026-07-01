let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.02" in
{
  name = "nasm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.nasm.us/pub/nasm/releasebuilds/%{version}/nasm-%{version}.tar.xz",
      sha256 = "87336eba53b4acfe917424ab5d500d2b0054d9f5148d35c2273ccf2cfb712f0d",
      extract = true,
      strip_prefix = "nasm-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    ndisasm = { glob = "usr/bin/ndisasm" } | OutputBin,
    nasm = { glob = "usr/bin/nasm" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
    } | Attrs,
} | BuildSpec
