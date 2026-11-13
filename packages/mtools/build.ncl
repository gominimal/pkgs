let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.0.50" in
{
  name = "mtools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/mtools/mtools-%{version}.tar.gz",
      sha256 = "7f078accae7551c6b3a316ccd8296357329f7bbbc09583dcd1a2bbaeb081a7a4"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    bash, # several bundled helpers (mcomp, uz/lz, mxtar, tgz, mcheck, amuFormat.sh) are /bin/sh scripts
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      repology_project = "mtools",
      source_provenance = {
        category = 'GnuProject,
        name = "mtools",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/mtools --version",

    mmd_mcopy_roundtrip =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap],
        cmds = [
          # Build a blank FAT image, create a dir, copy a file in, and read it back.
          ["/bin/bash", "-c", "dd if=/dev/zero of=fat.img bs=1024 count=1440"],
          ["/bin/bash", "-c", "MTOOLS_SKIP_CHECK=1 mformat -i fat.img -f 1440 ::"],
          ["/bin/bash", "-c", "echo 'hello mtools' > src.txt"],
          ["/bin/bash", "-c", "MTOOLS_SKIP_CHECK=1 mmd -i fat.img ::/EFI"],
          ["/bin/bash", "-c", "MTOOLS_SKIP_CHECK=1 mcopy -i fat.img src.txt ::/EFI/src.txt"],
          ["/bin/bash", "-c", "MTOOLS_SKIP_CHECK=1 mcopy -i fat.img ::/EFI/src.txt out.txt"],
          ["/bin/bash", "-c", "grep -q '^hello mtools$' out.txt"],
        ],
      } | Test,
  },
} | BuildSpec
