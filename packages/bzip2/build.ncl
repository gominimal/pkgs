let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.0.8" in
{
  name = "bzip2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bzip2-%{version}.tar.gz",
      sha256 = "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269"
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
    # Technically a bunch of these binaries need a shell interpreter, but given how low level this
    # package is its better not to bring in bash at this level.
    bunzip2 = { glob = "usr/bin/bunzip2" } | OutputBin,
    bzcat = { glob = "usr/bin/bzcat" } | OutputBin,
    bzcmp = { glob = "usr/bin/bzcmp", allow_missing_interpreter = true } | OutputBin,
    bzdiff = { glob = "usr/bin/bzdiff", allow_missing_interpreter = true } | OutputBin,
    bzegrep = { glob = "usr/bin/bzegrep", allow_missing_interpreter = true } | OutputBin,
    bzfgrep = { glob = "usr/bin/bzfgrep", allow_missing_interpreter = true } | OutputBin,
    bzgrep = { glob = "usr/bin/bzgrep", allow_missing_interpreter = true } | OutputBin,
    bzip2 = { glob = "usr/bin/bzip2" } | OutputBin,
    bzip2recover = { glob = "usr/bin/bzip2recover" } | OutputBin,
    bzless = { glob = "usr/bin/bzless", allow_missing_interpreter = true } | OutputBin,
    bzmore = { glob = "usr/bin/bzmore", allow_missing_interpreter = true } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,

    headers = { glob = "usr/include/bzlib.h" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "bzip2 (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT (amd64): built from source by stage0-bzip2-amd on the toolchain whose
              # gcc/glibc roots are ours (glibc-bedrock-2.42 measured 97/97 byte-identical).
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: foreign prebuilts were in the build sandbox and appear in
              # provenance as BUILD INPUTS. Not hex0-rooted.
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/f0ca29551a5acbf1c1a3a80f84bde8bd4de0e3900228ca6c6c38795e65153081/stage0-bzip2-amd-x86_64.tar.zst",
              sha256 = "f0ca29551a5acbf1c1a3a80f84bde8bd4de0e3900228ca6c6c38795e65153081",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: built from source by stage0-bzip2-arm on our hex0-rooted toolchain.
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET.
              # GENERATION 1: compiled with foreign prebuilts in the sandbox; they are BUILD
              # INPUTS and appear in provenance. Not hex0-rooted.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/822a8e483cee828132ae497518796f7db13d5ef9f585457dce79afaca0124c79/stage0-bzip2-arm-aarch64.tar.zst",
              sha256 = "822a8e483cee828132ae497518796f7db13d5ef9f585457dce79afaca0124c79",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {},
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "bzip2-1.0.6",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libarchive",
        repo = "bzip2",
      },
    } | Attrs,
} | BuildSpec
