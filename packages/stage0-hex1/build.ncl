let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let hex0 = import "../hex0/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# stage0-hex1: first from-source rung of the amd64 bootstrap ladder, driven by bash
# and coreutils. build.sh re-assembles hex0 from hex0_AMD64.hex0 with the seed and
# asserts byte-identity via sha256sum, then assembles hex1 with the rebuilt hex0.
# Sources: the recursive stage0-posix-1.9.1 tree (sha-pinned tarball, incl. the AMD64
# submodule). Outputs are static ELFs with no .interp, so no runtime_deps and
# allow_missing_interpreter on each OutputBin.
let amd64_spec =
  {
    name = "stage0-hex1",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
        sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df",
        extract = true,
      } | Source,
      hex0, # seed, installed in the rootfs at /usr/bin/hex0
      bash, # build.sh interpreter
      coreutils, # sha256sum/cut/head/od/tr/cp/mkdir/chmod
    ],
    cmd = "./build.sh",
    outputs = {
      # rebuilt hex0, byte-identical to the seed
      hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
      hex1 = { glob = "usr/bin/hex1", allow_missing_interpreter = true } | OutputBin,
    },
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-hex1",
      build_deps = [],
    } | BuildSpec,
} target
