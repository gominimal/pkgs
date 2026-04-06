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
              url = "gs://minimal-staging-archives/prebuilts/bzip2/75355884e09794f5aa09558214ab877cfd1d026cf1f888d093ecfe6dd762ee85.tar.zst",
              sha256 = "30161bb4830b54bd007e1f4c9188e98b9d310d119d31bb0ab65b12a4a43cdaea",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/bzip2/arm64-linux-gnu/bzip2_1.0.8_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "59684a904c14cbc161a743692366a112f211e2ce51e38cc92ae2476aaf961a52",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {},
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "libarchive",
        repo = "bzip2",
      },
    } | Attrs,
} | BuildSpec
