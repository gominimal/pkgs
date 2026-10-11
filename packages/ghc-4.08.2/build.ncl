let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-4.08.2: the first GHC of the source-only ladder (microhs-0.16 -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 ->
# 7.0.4 -> 7.6.3 -> ...). GHC 4.08.2's compiler is compiled by MicroHs from a desugared copy of its own sources, that
# compiler compiles the libraries and itself to C, and gcc links the native compiler. Installs the in-place tree at
# /usr/lib/ghc-4.08.2/w plus bin/ghc-4.08.2 for the next rung; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/: the 4.08.2 and happy 1.16 tarballs, the gnu-config pair, and the
# first-party overlay (desugared modules D/, shims S/, 30 patches, build scripts, 27 tests with reference outputs).
# No `needs`: nothing here touches the network. amd64 only (see the match at the bottom).
# pkgmgr: bootstrap_rung = "ghc"
let microhs-0-16 = import "../microhs-0.16/build.ncl" in # the Haskell compiler that hosts hsc
let gmp = import "../gmp/build.ncl" in # the RTS's Integer
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # the C compiler, hex0-rooted; build.sh wraps it against the sysroot
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let toolchain = import "../toolchain/build.ncl" in # aarch64: gcc, binutils and glibc, built from the hex0 seed
let glibc = import "../glibc/build.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in # the driver and the utilities are Perl
let python = import "../python/build.ncl" in # the desugaring and interface-fixing scripts
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let patch = import "../patch/build.ncl" in
let version = "4.08.2" in
let is_arm = target.arch == 'Arm64 in
# x86_64 compiles with the bedrock gcc against its glibc sysroot; aarch64 with the toolchain, itself hex0-rooted
let cc_build = if is_arm then [toolchain] else [gcc-bedrock, binutils-bedrock, glibc-bedrock] in
let cc_runtime = if is_arm then [glibc, toolchain] else [subsetOf glibc-bedrock ["sysroot_lib"], gcc-bedrock, binutils-bedrock] in
let spec =
  {
    name = "ghc-4.08.2",
    build_deps =
      [
        { file = "build.sh" } | Local,
        # Import-ordered parallel scheduler for the library and gen1 compiles.
        { file = "dagbuild.py" } | Local,
        {
          url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.bz2",
          sha256 = "38dc3e1ef888013383d205a8991e1d16f44d4e60f58523dde6bb64467cb7242b",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        {
          url = "gs://minimal-staging-archives/happy-1.16.tar.gz",
          sha256 = "4da47f4904dbdddfb58140edb0395383feba72dfc77759e57587a526dd9496c5",
          extract = false,
        } | Source,
        # first-party: what makes 4.08.2 compile on MicroHs and on a 64-bit modern toolchain. Text only; the
        # generators that produced D/ from the compiler sources (step1c.sh, desugar.py, hiboot2hsboot.py) ride along.
        {
          url = "gs://minimal-staging-archives/ghc-4.08.2-microhs-overlay.tar.gz",
          sha256 = "2727566c55180867bee9861d485d379d9cab264dc0fab03a5df5a52c1d013a39",
          extract = false,
        } | Source,
        # the tarball's 2001 config.guess/config.sub predate x86_64; the modern GNU pair replaces them
        {
          url = "gs://minimal-staging-archives/build-aux/gnu-config-config.guess",
          sha256 = "e3d148130e9151735f8b9a8e69a70d06890ece51468a9762eb7ac0feddddcc2f",
          extract = false,
        } | Source,
        {
          url = "gs://minimal-staging-archives/build-aux/gnu-config-config.sub",
          sha256 = "11c54f55c3ac99e5d2c3dc2bb0bcccbf69f8223cc68f6b2438daa806cf0d16d8",
          extract = false,
        } | Source,
        microhs-0-16,
        gmp,
        base,
        bash,
        make,
        perl,
        python,
        sed,
        grep,
        gawk,
        coreutils,
        findutils,
        diffutils,
        tar,
        bzip2,
        gzip,
        patch,
      ]
      @ cc_build,
    # the driver is Perl and runs gcc on the C hsc emits; the RTS links libgmp
    runtime_deps =
      [
        gmp,
        perl,
      ]
      @ cc_runtime,
    cmd = "./build.sh",
    outputs = {
      prefix = { glob = "usr/lib/ghc-4.08.2/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        repology_project = "ghc",
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/4.08.2/",
        },
      } | Attrs,
  } | BuildSpec
in
spec
