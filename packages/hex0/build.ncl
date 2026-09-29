let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# hex0: the per-arch seed binary of the bootstrap ladder, the hex0 monitor from
# oriansj/stage0-posix Release_1.9.1 (229-byte ELF64 AMD64 / 526-byte ELF64 AArch64).
# Input: a sha-pinned zstd tarball holding the seed at usr/bin/hex0. The tarball sha
# below gates the fetched bytes; build.sh re-checks the inner ELF sha and byte count
# (amd64 66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b, 229 B;
# aarch64 8ca9745e20af3f0d6037684cbc3ec3789c205d86ccecf43f77d0aeabf16050b4, 526 B).
# Provenance: stage0-posix supermodule 45d90f5955b6907dc6cdea9ebafce558359edcd3,
# bootstrap-seeds submodule cedec6b8066d1db229b6c77d42d120a23c6980ed; each seed is
# byte-identical to its annotated source hex0_<ARCH>.hex0 with comments stripped.
{
  name = "hex0",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-staging-archives/seeds/stage0-posix/Release_1.9.1/hex0-seed-amd64.tar.zst",
          sha256 = "be2533eccbd0547e50a9bce4fd6571727365b0896b65fecbb232a623b1f36959",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-staging-archives/seeds/stage0-posix/Release_1.9.1/hex0-seed-aarch64.tar.zst",
          sha256 = "26ac8cf801eac4e415e82af60dc0f6a13176466d425a08cd7d4b63e20b7f087a",
          extract = true,
        } | Source,
    } target,
    (import "../bash-bootstrap/build.ncl"), # /bin/sh for build.sh
    (import "../coreutils/build.ncl"), # sha256sum/wc/cp/mkdir/chmod
  ],
  cmd = "./build.sh",
  outputs = {
    # the seed is a static ELF with no .interp
    hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec
