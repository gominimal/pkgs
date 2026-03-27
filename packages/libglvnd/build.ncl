let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in

let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.7.0" in
{
  name = "libglvnd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/NVIDIA/libglvnd/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "073e7292788d4d3eeb45ea6c7bdcce9bfdb3b3eef8d7dbd47f2f30dce046ef98",
      extract = true,
      strip_prefix = "libglvnd-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    python,
    toolchain,
    xorgproto,
  ],
  runtime_deps = [
    libx11,
    libxext,
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/lib{EGL,GL,GLX,OpenGL,GLdispatch,GLESv}*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libGLdispatch.so.0"],
          ["/bin/bash", "-c", "test -f /usr/lib/libOpenGL.so.0"],
          ["/bin/bash", "-c", "test -f /usr/lib/libEGL.so.1"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "NVIDIA",
        repo = "libglvnd",
      },
    } | Attrs,
} | BuildSpec
