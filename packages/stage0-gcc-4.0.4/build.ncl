let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-gcc-4.0.4: gcc-core 4.0.4 (cc1, xgcc, cpp, libgcc.a) built by tcc-musl2 and linked against
# the musl sysroot at /usr/lib/musl-bedrock, with as/ld/ar/ranlib from stage0-binutils-2.30. The
# tarball ships every generated file, so no autotools/bison/flex are needed; the shipped 2005
# config.sub already knows x86_64-linux-gnu. See build.sh.
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in # CC: /usr/bin/tcc-musl2 + /usr/lib/tcc/libtcc1.a
let stage0-musl-r4 = import "../stage0-musl-1.1.24-cc2/build.ncl" in # link target: musl libc.a + crt + headers, and the /usr/lib/musl-bedrock sysroot
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in # as/ld/ar/ranlib/nm on PATH (xgcc assembles libgcc via as)
let bash = import "../bash/build.ncl" in # build.sh + configure shell
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # source seds
let grep = import "../grep/build.ncl" in # configure probes
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in # .tar.bz2 source
let findutils = import "../findutils/build.ncl" in # mtime guard: find . -exec touch
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # configure's awk
let version = "4.0.4" in
let amd64_spec =
  {
    name = "stage0-gcc-4.0.4",
    build_deps = [
      { file = "build.sh" } | Local,
      # Byte-identity pins, checked by the (currently disabled) sha256sum gate at the end of build.sh.
      { file = "stage0.answers" } | Local,
      {
        # gcc-core 4.0.4 (.tar.bz2); sha from live-bootstrap steps/gcc-4.0.4/sources. extract=false:
        # build.sh untars with --no-same-owner.
        url = "gs://minimal-staging-archives/gcc-core-%{version}.tar.bz2",
        sha256 = "e9bf58c761a4f988311aef6b41f12fd5c7e51d09477468fb73826aecc1be32e7",
        extract = false,
      } | Source,
      stage0-tcc-musl-s4, # CC (via the musl-cc wrapper) + AR="tcc-musl2 -ar"
      stage0-musl-r4, # static link target
      stage0-binutils-r5, # as/ld/ar/ranlib/nm on PATH
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      bzip2,
      findutils,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    cmd = "./build.sh",
    outputs = {
      # gcc/cpp/gcov + the x86_64-linux-gnu-prefixed driver. allow_executable: ELF programs kept as
      # OutputData because they carry the stage0 musl interpreter, which OutputBin's checker rejects.
      bin = { glob = "usr/bin/*", allow_executable = true } | OutputData,
      # cc1 + collect2
      libexec = { glob = "usr/libexec/**", allow_executable = true } | OutputData,
      # libgcc.a + crtbegin/crtend.o + specs + gcc's internal headers. libgcc.a lives under
      # usr/lib/gcc/<target>/<ver>/ and is found via gcc's own search path, so OutputData over the
      # subtree suffices.
      internals = { glob = "usr/lib/gcc/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "gcc",
      } | Attrs,
  } | BuildSpec
in
# This package exists on amd64 only (the amd64 bootstrap chain). On arm64 the spec is an empty
# collection: no build runs and nothing on the arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-gcc-4.0.4",
      build_deps = [],
    } | BuildSpec,
} target
