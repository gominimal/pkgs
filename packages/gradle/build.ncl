let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

let version = "9.3.1" in
{
  name = "gradle",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://services.gradle.org/distributions/gradle-%{version}-bin.zip",
      sha256 = "b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06",
    } | Source,
    base,
    python,
  ],
  runtime_deps = [
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    gradle = { glob = "usr/bin/gradle" } | OutputBin,
    gradle_home = { glob = "usr/share/gradle/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "gradle --version 2>&1 | grep -q 'Gradle'"],
        ],
      } | Test,
  },
} | BuildSpec
