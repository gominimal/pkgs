let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
{
  name = "bzip2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bzip2-1.0.8.tar.gz",
      sha256 = "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bunzip2 = { glob = "usr/bin/bunzip2" } | OutputBin,
    bzcat = { glob = "usr/bin/bzcat" } | OutputBin,
    bzcmp = { glob = "usr/bin/bzcmp" } | OutputBin,
    bzdiff = { glob = "usr/bin/bzdiff" } | OutputBin,
    bzegrep = { glob = "usr/bin/bzegrep" } | OutputBin,
    bzfgrep = { glob = "usr/bin/bzfgrep" } | OutputBin,
    bzgrep = { glob = "usr/bin/bzgrep" } | OutputBin,
    bzip2 = { glob = "usr/bin/bzip2" } | OutputBin,
    bzip2recover = { glob = "usr/bin/bzip2recover" } | OutputBin,
    bzless = { glob = "usr/bin/bzless" } | OutputBin,
    bzmore = { glob = "usr/bin/bzmore" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,

    headers = { glob = "usr/include/bzlib.h" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "bzip2 (prebuilt)",
      prebuilt = true,
      inputs = [
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
              sha256 = "b63624201dd389a5f5e035604aab47c52023f0e72e2161238c0c3feaa28771cd",
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
