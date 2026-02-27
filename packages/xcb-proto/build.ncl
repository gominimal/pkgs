let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in

let version = "1.17.0" in
{
  name = "xcb-proto",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xcb-proto-%{version}.tar.xz",
      sha256 = "2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c",
      extract = true,
      strip_prefix = "xcb-proto-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    python,
  ],
  runtime_deps = [],

  cmd = "./build.sh",

  outputs = {
    xcb-xml = { glob = "usr/share/xcb/**" } | OutputData,
    pkgconfig = { glob = "usr/share/pkgconfig/*.pc" } | OutputData,
    xcbgen = { glob = "usr/lib/python*/site-packages/xcbgen/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
