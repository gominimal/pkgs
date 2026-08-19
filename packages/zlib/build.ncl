let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.2" in
{
  name = "zlib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zlib-%{version}.tar.gz",
      sha256 = "b99a0b86c0ba9360ec7e78c4f1e43b1cbdf1e6936c8fa0f6835c0cd694a495a1"
    } | Source,
    bash-bootstrap,
    make,
    sed,
    tar,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libz = { glob = "usr/lib/libz.so*" } | OutputLib,
    zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
    zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "zlib (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT (amd64): built from source by stage0-zlib-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/717d2671877766c03338838d2072f4b3db719827f387fa7ade4daf74d13083ab/stage0-zlib-amd-x86_64.tar.zst",
              sha256 = "717d2671877766c03338838d2072f4b3db719827f387fa7ade4daf74d13083ab",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): built from source by stage0-zlib-arm on the toolchain whose
              # gcc/binutils/glibc roots are our own hex0-rooted artifacts. 42 gcc invocations,
              # verified against THIS package's own output globs before repointing:
              #   usr/lib/libz.so*  -> libz.so, libz.so.1, libz.so.1.3.2
              #   usr/include/{zconf.h,zlib.h}   usr/lib/pkgconfig/zlib.pc
              # GATED ON SLOT CONTENTS, not declared outputs (bin/queue/slot-compare.py):
              #   old slot 8 files, new 8 files, only libz.so.1.3.1 -> libz.so.1.3.2
              #   VERDICT: SLOT_SUPERSET
              # The first promotion of this slot used the declared-output check instead and
              # silently dropped usr/lib/libz.a + the man page, because a PREBUILT slot delivers
              # its WHOLE tarball (materialize_prebuilt never calls match_outputs_into) while a
              # from-source spec is filtered to declarations. Comparing declarations cannot catch
              # that; comparing slot contents does.
              #
              # ⚠️ VERSION CHANGE 1.3.1 -> 1.3.2 (the from-source recipe builds 1.3.2).
              # ⚠️ GENERATION 1: built in a sandbox populated by foreign prebuilts. The OUTPUT is
              # from source; the foreign packages are BUILD INPUTS and appear in provenance. Not
              # yet hex0-rooted. The close is a generation-2 rebuild + fixed-point check.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/d3b6f8f598e48ff5e8a062b3a65fa97fcbd895ddb173cfe9bde0ee855c783d4a/stage0-zlib-arm-aarch64.tar.zst",
              sha256 = "d3b6f8f598e48ff5e8a062b3a65fa97fcbd895ddb173cfe9bde0ee855c783d4a",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        libz = { glob = "usr/lib/libz.so*" } | OutputLib,
        zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
        zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
        pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "madler",
        repo = "zlib",
      },
    } | Attrs,
} | BuildSpec
