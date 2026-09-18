let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-linux-headers-6.12.43: the kernel UAPI headers from linux-6.12.43 (same source and sha as
# the production linux_headers package), exported with `make headers` using stage0-gcc-10.4.0 as
# HOSTCC for the one host tool (scripts/unifdef). The headers are libc-independent, so the compiler
# choice cannot change the output. stage0-gcc-10.4.0 is the only gcc in the closure, so /usr/bin/gcc
# is unambiguous. See build.sh.
let stage0-gcc-10-4-0 = import "../stage0-gcc-10.4.0/build.ncl" in # HOSTCC for unifdef
let stage0-binutils-2-41 = import "../stage0-binutils-2.41/build.ncl" in # as/ld for the host gcc
let stage0-musl-1-2-5 = import "../stage0-musl-1.2.5/build.ncl" in # /usr/lib/musl-bedrock-1.2.5 sysroot (static link)
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in # .tar.xz source
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # kernel Makefiles use awk
let version = "6.12.43" in
let amd64_spec =
  {
    name = "stage0-linux-headers-6.12.43",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # same source and sha as the production linux_headers package. extract=false: build.sh
        # untars with --no-same-owner.
        url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
        sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee",
        extract = false,
      } | Source,
      stage0-gcc-10-4-0, # HOSTCC (via the gcc-cc wrapper in build.sh)
      stage0-binutils-2-41, # as/ld/ar/ranlib
      stage0-musl-1-2-5, # static musl sysroot
      bash,
      make,
      sed,
      grep,
      diffutils,
      coreutils,
      tar,
      xz,
      findutils,
      gawk-bootstrap,
    ],
    build_args = {
      include version,
    },
    cmd = "./build.sh",
    outputs = {
      # the exported UAPI tree usr/include/{linux,asm,asm-generic,drm,misc,...}; same glob as the
      # production linux_headers package (kernel UAPI has only subdirs, no top-level *.h).
      includes = { glob = "usr/include/*/**" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        repology_project = "linux",
        source_provenance = {
          category = 'GithubRepo,
          owner = "torvalds",
          repo = "linux",
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
      name = "stage0-linux-headers-6.12.43",
      build_deps = [],
    } | BuildSpec,
} target
