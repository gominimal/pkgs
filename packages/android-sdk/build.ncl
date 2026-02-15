let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

let version = "11076708" in
{
  name = "android-sdk",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://dl.google.com/android/repository/commandlinetools-linux-%{version}_latest.zip",
      sha256 = "2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258",
    } | Source,
    base,
    jdk,
    python,
  ],
  runtime_deps = [
    jdk,
    base,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    sdk = { glob = "usr/lib/android-sdk/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    sdkmanager_version =
      {
        class = 'Standalone,
        test_deps = [base, jdk],
        cmds = [
          ["/bin/bash", "-c", "sdkmanager --version"],
        ],
      } | Test,
  },
} | BuildSpec
