let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# glibc-bedrock-2.42: the glibc-2.42 source built cold from
# source by stage0-gcc-15.2.0 and stage0-binutils-2.41, with musl (stage0-musl-1.2.5) as the host
# compiler's own libc for BUILD_CC only. Unlike the production glibc package (a native rebuild with
# glibc already in /usr), this is a headers-first cross-style build: a distinct host triple so
# configure skips AC_TRY_RUN probes, pass 1 installs headers + crt + a stub libc.so into a staging
# sysroot, an optional pass 2 rebuilds libgcc against glibc, pass 3 builds glibc itself. Outputs the
# plain /usr layout plus a versioned single-writer sysroot at usr/lib/glibc-bedrock-2.42. See build.sh.
let stage0-gcc-15-2-0 = import "../stage0-gcc-15.2.0/build.ncl" in # CC/CXX (musl-linked, --disable-shared)
let stage0-binutils-2-41 = import "../stage0-binutils-2.41/build.ncl" in # as/ld/ar/ranlib (glibc-2.42 needs binutils >= 2.39)
let stage0-linux-headers-6-12-43 = import "../stage0-linux-headers-6.12.43/build.ncl" in # kernel UAPI at /usr/include/{linux,asm,asm-generic}
let stage0-musl-1-2-5 = import "../stage0-musl-1.2.5/build.ncl" in # /usr/lib/musl-bedrock-1.2.5: the host compiler's own libc, BUILD_CC only
let stage0-gmp-mpfr-mpc = import "../stage0-gmp-mpfr-mpc/build.ncl" in # /usr/lib/gcc-math, used only if pass 2 runs
# build tools, matching the production glibc package
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in # full gawk (gen-tunables.awk / gen-sorted.awk / errlist.awk), not gawk-bootstrap
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in # tests/mtrace only; not build-required
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# other tools configure aborts without
let bison = import "../bison/build.ncl" in # intl/plural.c is not shipped in the 2.42 tarball, so bison always regenerates it
let m4 = import "../m4/build.ncl" in # bison runtime dep
let python = import "../python/build.ncl" in # gen-as-const.py
let version = "2.42" in

# Outputs follow the production glibc package (plain /usr, --prefix=/usr, libc_cv_slibdir=/usr/lib),
# plus two globs for the versioned single-writer sysroot that consumers build against with -nostdinc.
let all_outputs = {
  # xtrace and ldd depend on bash; omitted as a dep given how low-level glibc is.
  bins = { glob = "usr/bin/**", allow_missing_interpreter = true } | OutputBin,
  sbins = { glob = "usr/sbin/**" } | OutputBin,
  etc = { glob = "etc/**/*" } | OutputData,

  # No top-level usr/lib/*.{so,a} or crt*.o globs: as a build dep, this package's libc.so.6 would
  # shadow the sandbox's runtime libc in the merged /usr/lib and break the toolchain-linked userland.
  # Every in-tree consumer uses only the versioned sysroot below. If the plain /usr layout including
  # the top-level libs is ever needed from this package, re-add for that run only:
  #   libs = usr/lib/*.{so*,a} (allow_data: libc.so is a linker script)
  #   crts = usr/lib/{crt,gcrt,grcrt,Mcrt,rcrt,Scrt}*.o
  lib_audit = { glob = "usr/lib/audit/*.so*" } | OutputLib,
  lib_locale = { glob = "usr/lib/locale/**" } | OutputData,
  lib_gconv = { glob = "usr/lib/gconv/**", allow_data = true } | OutputLib,

  libexec_getconf = { glob = "usr/libexec/getconf/**" } | OutputLib,

  i18n = { glob = "usr/share/i18n/**" } | OutputData,
  locales = { glob = "usr/share/locale/**" } | OutputData,

  includes = { glob = "usr/include/**" } | OutputData,

  # the versioned single-writer sysroot. The single-level usr/lib globs above do not match this
  # nested path (literal_separator), so nothing is captured twice. libc.so is a linker script, hence
  # allow_data on sysroot_lib.
  sysroot_lib = { glob = "usr/lib/glibc-bedrock-2.42/lib/**", allow_data = true } | OutputLib,
  sysroot_include = { glob = "usr/lib/glibc-bedrock-2.42/include/**" } | OutputData,
}
in
let amd64_spec =
  {
    name = "glibc-bedrock-2.42",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # glibc-2.42 tarball (upstream:
        # https://ftp.gnu.org/gnu/glibc/). extract=false: build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/glibc-%{version}.tar.xz",
        sha256 = "d1775e32e4628e64ef930f435b67bb63af7599acb6be2b335b9f19f16509f17f",
        extract = false,
      } | Source,
      {
        # gcc-15.2.0 source, needed only for the optional pass-2 libgcc rebuild (B4_REBUILD_LIBGCC=1);
        # same sha as stage0-gcc-15.2.0. build.sh untars it only inside that branch, so by default it
        # is fetched but unused. Declared here so the recipe covers both modes. extract=false.
        # The gcc version is hardcoded to match GCCVER in build.sh.
        url = "gs://minimal-staging-archives/gcc-15.2.0.tar.xz",
        sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e",
        extract = false,
      } | Source,
      # toolchain
      stage0-gcc-15-2-0,
      stage0-binutils-2-41,
      stage0-linux-headers-6-12-43,
      stage0-musl-1-2-5,
      stage0-gmp-mpfr-mpc,
      # build tools
      bash,
      bzip2,
      coreutils,
      diffutils,
      file,
      findutils,
      gawk,
      grep,
      gzip,
      make,
      perl,
      sed,
      tar,
      xz,
      # other
      bison,
      m4,
      python,
    ],

    cmd = "./build.sh",
    build_args = {
      include version,
    },

    outputs = all_outputs,
    attrs =
      {
        upstream_version = version,
        repology_project = "glibc",
        source_provenance = {
          category = 'GnuProject,
          name = "glibc",
        },
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "glibc-bedrock-2.42",
      build_deps = [],
    } | BuildSpec,
} target
