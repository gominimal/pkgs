let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14" in
{
  name = "gzip",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gzip-%{version}.tar.xz",
      sha256 = "01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    # Technically bins like zgrep depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      repology_project = "gzip",
      source_provenance = {
        category = 'GnuProject,
        name = "gzip",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "gzip (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT (amd64): built from source by stage0-gzip-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/402a6c0ca6a7eef04f8dba190a32f9a146dad079e6bb64dce5adffb37431ba52/stage0-gzip-amd-x86_64.tar.zst",
              sha256 = "402a6c0ca6a7eef04f8dba190a32f9a146dad079e6bb64dce5adffb37431ba52",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: built from source by stage0-gzip-arm on our hex0-rooted toolchain.
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET (delivers everything
              # the foreign tarball did). That check compares SLOT CONTENTS, not declared
              # outputs, because materialize_prebuilt ships a prebuilt whole and a declared-
              # output check therefore cannot see a removal.
              # GENERATION 1: compiled in a sandbox populated by foreign prebuilts. Output is
              # from source; foreign packages are BUILD INPUTS and appear in provenance.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/e733b43e8cca05c5587ccbb381ae93a3070c3da2c0767130e2c6582c465e7e53/stage0-gzip-arm-aarch64.tar.zst",
              sha256 = "e733b43e8cca05c5587ccbb381ae93a3070c3da2c0767130e2c6582c465e7e53",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        binaries = { glob = "usr/bin/*" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/gzip --version",

    zip_unzip =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "echo 'compress me' > original.txt"],
          ["/bin/bash", "-c", "cp original.txt original_copy.txt"],
          ["/bin/gzip", "original.txt"],
          ["/bin/bash", "-c", "test -f original.txt.gz"], # verify .gz exists
          ["/bin/gunzip", "original.txt.gz"],
          ["/bin/diff", "-q", "original.txt", "original_copy.txt"], # verify roundtrip
        ],
      } | Test,
  },
} | BuildSpec
