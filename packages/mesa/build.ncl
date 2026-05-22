let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let py-packaging = import "../py-packaging/build.ncl" in
let py-mako = import "../py-mako/build.ncl" in
let py-markupsafe = import "../py-markupsafe/build.ncl" in
let py-pyyaml = import "../py-pyyaml/build.ncl" in
let bison = import "../bison/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in

let libdrm = import "../libdrm/build.ncl" in
let libxcb = import "../libxcb/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxfixes = import "../libxfixes/build.ncl" in
let libxrandr = import "../libxrandr/build.ncl" in
let libxshmfence = import "../libxshmfence/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let expat = import "../expat/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "25.3.5" in
{
  name = "mesa",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mesa-%{version}.tar.xz",
      sha256 = "be472413475082df945e0f9be34f5af008baa03eb357e067ce5a611a2d44c44b",
      extract = true,
      strip_prefix = "mesa-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
    python,
    # py-packaging provides distutils-equivalent metadata that mesa's
    # meson.build:966 requires. Without this, build fails with
    # "One of Python (3.x) packaging or distutils module is required".
    py-packaging,
    # py-mako: required by meson.build:964 ("mako >= 0.8.0 required").
    # py-markupsafe: hidden mako runtime dep (PyPI requires_dist:
    # 'MarkupSafe>=0.9.2'). mako.filters.html_escape imports it at
    # mako-template-load time. Without this, mesa's first ir_expression_
    # operation.py invocation 500s with "ModuleNotFoundError: markupsafe".
    # py-pyyaml: read by various mesa generator scripts at build time.
    # The pip3 install fallback in build.sh is silently a no-op in the
    # hermetic sandbox (no network), so these MUST come in as build_deps.
    py-mako,
    py-markupsafe,
    py-pyyaml,
    bison,
    flex,
    m4,
    xorgproto,
  ],
  runtime_deps = [
    libdrm,
    libxcb,
    libx11,
    libxext,
    libxfixes,
    libxrandr,
    libxshmfence,
    expat,
    zlib,
    glibc,
    subsetOf gcc ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/lib{gbm,EGL,GL,GLESv,glapi,gallium}*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    drivers = { glob = "usr/lib/dri/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
