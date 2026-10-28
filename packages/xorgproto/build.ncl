let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let version = "2026.1" in
{
  name = "xorgproto",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xorgproto-%{version}.tar.xz",
      sha256 = "f9bfe4a9ed8c8ab9d2a3b0d49797f046052dadd06b7a8b45dbffaffb137e8290",
      extract = true,
      strip_prefix = "xorgproto-%{version}",
    } | Source,
    base,
    toolchain,
    meson,
    ninja,
  ],
  runtime_deps = [],

  cmd = "./build.sh",

  outputs = {
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/share/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause AND HPND AND HPND-sell-variant AND ICU AND MIT AND MIT-open-group AND SGI-B-2.0 AND SMLNJ AND X11 AND X11-distribute-modifications-variant",
    } | Attrs,
} | BuildSpec
