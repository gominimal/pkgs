let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.01" in
{
  name = "nasm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.nasm.us/pub/nasm/releasebuilds/%{version}/nasm-%{version}.tar.xz",
      sha256 = "b7324cbe86e767b65f26f467ed8b12ad80e124e3ccb89076855c98e43a9eddd4",
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
    } | Attrs,
} | BuildSpec
