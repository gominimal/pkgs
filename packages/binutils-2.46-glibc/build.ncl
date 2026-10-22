let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# binutils-2.46-glibc: the binutils-2.46.0 source built
# by stage0-gcc-15.2.0 and linked glibc-dynamic against glibc-bedrock-2.42 (shared libbfd.so,
# interp under /usr/lib/glibc-bedrock-2.42/lib), assembled by stage0-binutils-2.41, with the
# production binutils configure flags. gold and gprofng stay disabled: they are C++ and would link
# the host's musl-built libstdc++.a into a glibc binary. See build.sh.
let stage0-gcc-15-2-0 = import "../stage0-gcc-15.2.0/build.ncl" in # CC, retargeted to glibc via -B/-L/-isystem in build.sh
let stage0-binutils-2-41 = import "../stage0-binutils-2.41/build.ncl" in # as/ld/ar/ranlib on PATH for the host gcc
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # target glibc sysroot at /usr/lib/glibc-bedrock-2.42 (kernel UAPI co-located)
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # .tar.xz source
let diffutils = import "../diffutils/build.ncl" in # configure's cmp/diff
let findutils = import "../findutils/build.ncl" in # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
# pkgmgr: bootstrap_rung = "hex0"
let version = "2.46.0" in
# Shared by the from-source spec and the sealed (switch-off) spec below.
let all_runtime_deps = [
  subsetOf glibc-bedrock ["sysroot_lib"],
]
in
let all_outputs = {
  # as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip + addr2line/c++filt/size/strings + the
  # x86_64-linux-gnu-<tool> symlinks. allow_executable: ELF programs exported as OutputData rather
  # than OutputBin because consumers reach them by absolute path under this package's own prefix.
  bin = { glob = "usr/bin/*", allow_executable = true } | OutputData,
  # libbfd.so*/libopcodes.so* (--enable-shared) plus the .a files
  libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
  # bfd-plugins dir (--enable-plugins) + ldscripts
  bfdplugins = { glob = "usr/lib/bfd-plugins/**" } | OutputLib,
  ldscripts = { glob = "usr/lib/ldscripts/*" } | OutputData,
  # bfd.h / ansidecl.h / ...
  headers = { glob = "usr/include/**" } | OutputData,
  # No etc output: production's etc/gprofng.rc comes from gprofng, which is disabled here, and an
  # empty glob fails output enumeration.
}
in
let amd64_spec =
  {
    name = "binutils-2.46-glibc",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # no byte-identity pins for this package; see the file
      {
        # binutils-2.46.0 tarball. extract=false:
        # build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
        sha256 = "d75a94f4d73e7a4086f7513e67e439e8fcdcbb726ffe63f4661744e6256b2cf2",
        extract = false,
      } | Source,
      stage0-gcc-15-2-0, # CC via the gcc-cc wrapper (glibc-targeted, no -static)
      stage0-binutils-2-41, # /usr/bin/{as,ld,ar,ranlib} for the host gcc
      glibc-bedrock, # target glibc sysroot
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      xz,
      diffutils,
      findutils,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    # The binaries are glibc-dynamic against the sysroot (interp + rpath under
    # /usr/lib/glibc-bedrock-2.42/lib), so its libc.so.6/libm.so.6/loader must be declared or the
    # missing-runtime_deps check fails. Only sysroot_lib: the full glibc-bedrock would put a second
    # usr/include and usr/bin next to the toolchain glibc in every consumer sandbox.
    # find_lib_in_deps globs `**/<soname>`, so the versioned sysroot path matches.
    runtime_deps = all_runtime_deps,

    cmd = "./build.sh",
    outputs = all_outputs,
    attrs =
      {
        upstream_version = version,
        repology_project = "binutils",
        source_provenance = {
          category = 'GnuProject,
          name = "binutils",
        },
      } | Attrs,
  } | BuildSpec
in
# This package builds on amd64 only, and only while hex0/amd64-ladder.ncl is enabled (the amd64
# bootstrap chain). While the switch is off, amd64 takes the sealed artifact below instead (no
# build); on arm64 the spec is an empty collection.
match {
  { arch = 'Amd64, .. } =>
    if (import "../hex0/amd64-ladder.ncl").enabled then
      amd64_spec
    else
      # SEALED (switch off): the same sha-pinned artifact the production toolchain
      # package already anchors on (see packages/binutils/build.ncl), with this
      # package's own outputs, so anything that imports it (the jvm ladder roots) gets a
      # real tree rather than an empty stub. Provenance: gominimal/minimermetic#16.
      (
        {
          name = "binutils-2.46-glibc",
          prebuilt = true,
          build_deps = [
            {
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/e796366aca5bb03f1e082598b4c3824ad3c95e0001b961a6d339da8c19f836bb/binutils-2.46-glibc-2.46.0.tar.zst",
              sha256 = "e796366aca5bb03f1e082598b4c3824ad3c95e0001b961a6d339da8c19f836bb",
              extract = true,
            } | Source,
          ],
          runtime_deps = all_runtime_deps,
          outputs = all_outputs,
        } | BuildSpec
      ),
  { arch = 'Arm64, .. } =>
    {
      name = "binutils-2.46-glibc",
      build_deps = [],
    } | BuildSpec,
} target
