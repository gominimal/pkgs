let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.0.8" in
{
  name = "bzip2",
  build_deps = [
    { file = "build.sh" } | Local,
    # Security backports for bzip2recover (shipped as usr/bin/bzip2recover)
    # from sourceware bzip2 master (https://sourceware.org/git/bzip2.git);
    # 1.0.8 is the latest release and gitlab.com/bzip2/bzip2 does not carry
    # them. Drop each once a release contains it.
    #   0001 CVE-2026-42250: off-by-one before tooManyBlocks wrote one past the
    #        bStart/bEnd/rbStart/rbEnd arrays (35d122a3df8b).
    #   0002 same fix set: reject a block whose end precedes its start, an
    #        unsigned underflow that passed the size check (6ab7670e74d3).
    #   0003 CWE-59, no CVE: create the predictable recNNNNN output files with
    #        O_EXCL|0600 so a planted symlink is not followed (f5dfc96063fe).
    { file = "0001-bzip2recover-CVE-2026-42250-max-handled-blocks.patch" } | Local,
    { file = "0002-bzip2recover-block-bounds-underflow.patch" } | Local,
    { file = "0003-bzip2recover-output-O_EXCL.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/bzip2-%{version}.tar.gz",
      sha256 = "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269"
    } | Source,
    base-bootstrap,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
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
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/0d5ffe1dae29fdc7f1fa832f1a50774edc2f20bd6617c1f0cd2d5b0731ce3d4a/bzip2-x86_64.tar.zst",
              sha256 = "0d5ffe1dae29fdc7f1fa832f1a50774edc2f20bd6617c1f0cd2d5b0731ce3d4a",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/a4f84d7ed690c7dad7c24318d944c985ac2208add6eeee1b06553dfe1e06d916/bzip2-aarch64.tar.zst",
              sha256 = "a4f84d7ed690c7dad7c24318d944c985ac2208add6eeee1b06553dfe1e06d916",
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

  tests = {
    smoketest = standaloneTest "/usr/bin/bzip2 --help",
  },
} | BuildSpec
