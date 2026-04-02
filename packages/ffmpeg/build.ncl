let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let dav1d = import "../dav1d/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let harfbuzz = import "../harfbuzz/build.ncl" in
let libass = import "../libass/build.ncl" in
let libaom = import "../libaom/build.ncl" in
let libfdk-aac = import "../libfdk-aac/build.ncl" in
let libopus = import "../libopus/build.ncl" in
let libsvtav1 = import "../libsvtav1/build.ncl" in
let libvmaf = import "../libvmaf/build.ncl" in
let libvpx = import "../libvpx/build.ncl" in
let libx264 = import "../libx264/build.ncl" in
let libx265 = import "../libx265/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.1" in
{
  name = "ffmpeg",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ffmpeg.org/releases/ffmpeg-%{version}.tar.xz",
      sha256 = "b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a",
      extract = true,
      strip_prefix = "ffmpeg-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    dav1d,
    fontconfig,
    freetype,
    fribidi,
    harfbuzz,
    libass,
    libaom,
    libfdk-aac,
    libopus,
    libsvtav1,
    libvmaf,
    libvpx,
    libx264,
    libx265,
    openssl,
    xz,
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    ffmpeg = { glob = "usr/bin/ffmpeg" } | OutputBin,
    ffprobe = { glob = "usr/bin/ffprobe" } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "ffmpeg",
      source_provenance = {
        category = 'GithubRepo,
        owner = "FFmpeg",
        repo = "FFmpeg",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
