# ARM BEDROCK VARIANT of the zlib root, second application of the pattern proven by
# stage0-linux-headers-arm (built, 1994 headers, 58/58 byte-identical across two build paths).
#
# Same shape: identical deps to the production recipe, but a DIFFERENT SPEC NAME, so it is not in
# its own transitive dep set and therefore not BOUND -- it builds FROM SOURCE against the toolchain
# whose gcc/binutils/glibc roots are now our own hex0-rooted artifacts. The resulting tarball is
# what zlib's replace_on_cycle would be repointed at.
#
# NOT a retirement by itself: zlib stays bound and keeps its breaker. This produces the ARTIFACT
# that lets the breaker point at something we built instead of something we downloaded.
let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.2" in
{
  name = "stage0-zlib-arm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zlib-%{version}.tar.gz",
      sha256 = "b99a0b86c0ba9360ec7e78c4f1e43b1cbdf1e6936c8fa0f6835c0cd694a495a1"
    } | Source,
    bash-bootstrap,
    make,
    sed,
    tar,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libz = { glob = "usr/lib/libz.so*" } | OutputLib,
    zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
    zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "madler",
        repo = "zlib",
      },
    } | Attrs,
} | BuildSpec
