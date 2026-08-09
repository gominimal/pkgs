let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ARM VARIANT of the linux_headers root. The existing stage0-linux-headers-6.12.43 rung depends on
# the pkgs stage0 LADDER (stage0-gcc-10.4.0 / stage0-binutils-2.41 / stage0-musl-1.2.5), which is
# amd64-SEEDED — stage0-hex1 hardcodes the amd64 seed sha, so that ladder dies at rung 0 on arm.
#
# arm does not need it. Its `gcc`, `binutils` and `glibc` roots already resolve, via
# replace_on_cycle, to our own hex0-rooted bedrock artifacts (measured: a full cold `base` build
# rc=0 against all three). So this spec depends on the ORDINARY toolchain packages and gets the
# bedrock compiler for free.
#
# It deliberately does NOT import `linux_headers` or `toolchain`, so it is not in its own
# transitive dep set and is therefore NOT bound — it should build FROM SOURCE.
let gcc = import "../gcc/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
# linux_headers IS a build dep, deliberately. `make headers` compiles exactly one host tool,
# scripts/unifdef, and glibc's errno.h chain reaches for <linux/errno.h> then <asm/errno.h>. On
# arm64 asm/errno.h is a GENERATED wrapper onto asm-generic that does not exist until later in the
# same build, so the host tool cannot compile without kernel headers already present.
#
# This does NOT make the spec bound: boundness is P in T(P), and linux_headers does not depend back
# on stage0-linux-headers-arm, so this spec stays out of its own transitive set and still builds
# from source.
#
# WHAT IT COSTS, stated plainly: generation 1 of our headers root is compiled with the FOREIGN
# headers prebuilt present in the sandbox. The OUTPUT is not derived from them -- usr/include comes
# from `make headers` over the kernel SOURCE -- but the foreign package is a build input and will
# appear in provenance. That is the ordinary bootstrap shape (a host compiler builds the first
# compiler); the honest close is a generation 2 built against generation 1 and a fixed-point check.
let linux_headers = import "../linux_headers/build.ncl" in
let version = "6.12.43" in
{
  name = "stage0-linux-headers-arm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee",
      extract = false,
    } | Source,
    gcc,
    binutils,
    glibc,
    bash-bootstrap,
    make,
    sed,
    grep,
    coreutils,
    tar,
    xz,
    findutils,
    gawk-bootstrap,
    linux_headers,
  ],
  cmd = "./build.sh",
  outputs = {
    includes = { glob = "usr/include/*/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
    } | Attrs,
} | BuildSpec
