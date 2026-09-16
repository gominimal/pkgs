let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# binutils-2.46-glibc: the production binutils-2.46.0 source (same sha as packages/binutils) built
# by stage0-gcc-15.2.0 and linked glibc-dynamic against glibc-bedrock-2.42 (shared libbfd.so,
# interp under /usr/lib/glibc-bedrock-2.42/lib), assembled by stage0-binutils-2.41, with the
# production binutils configure flags. gold and gprofng stay disabled: they are C++ and would link
# the host's musl-built libstdc++.a into a glibc binary. See build.sh.
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in # CC, retargeted to glibc via -B/-L/-isystem in build.sh
let stage0-binutils-r10 = import "../stage0-binutils-2.41/build.ncl" in # as/ld/ar/ranlib on PATH for the host gcc
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
let version = "2.46.0" in
let amd64_spec =
  {
    name = "binutils-2.46-glibc",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "stage0.answers" } | Local, # no byte-identity pins for this package; see the file
      match {
        { arch = 'Amd64, .. } =>
          {
            # production binutils-2.46.0 tarball, same sha as packages/binutils. extract=false:
            # build.sh untars with --no-same-owner.
            url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
            sha256 = "d75a94f4d73e7a4086f7513e67e439e8fcdcbb726ffe63f4661744e6256b2cf2",
            extract = false,
          } | Source,
        { arch = 'Arm64, .. } =>
          {
            # aarch64 prebuilt from the arm64 bootstrap chain: binutils 2.41, not 2.46 (no 2.46 arm
            # build exists yet). Root-shaped usr/ tree; build.sh extracts it verbatim.
            url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/58fd82c720a3885df8d07341eb822a5eb880c204eff1b7b0b5017ea769067c6b/stage0-binutils-2.41-aarch64.tar.zst",
            sha256 = "58fd82c720a3885df8d07341eb822a5eb880c204eff1b7b0b5017ea769067c6b",
            extract = false,
          } | Source,
      } target,
      stage0-gcc, # CC via the gcc-cc wrapper (glibc-targeted, no -static)
      stage0-binutils-r10, # /usr/bin/{as,ld,ar,ranlib} for the host gcc
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
    runtime_deps = [
      subsetOf glibc-bedrock ["sysroot_lib"],
    ],

    cmd = "./build.sh",
    outputs = {
      # as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip + addr2line/c++filt/size/strings + the
      # x86_64-linux-gnu-<tool> symlinks. allow_executable: ELF programs kept as OutputData because
      # they carry the sysroot interpreter, which OutputBin's checker rejects.
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
    },
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
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "binutils-2.46-glibc",
      build_deps = [],
    } | BuildSpec,
} target
