let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

let version = "9.6.1" in
{
  name = "gradle",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://services.gradle.org/distributions/gradle-%{version}-bin.zip",
      sha256 = "9c0f7faeeb306cb14e4279a3e084ca6b596894089a0638e68a07c945a32c9e14",
    } | Source,
    base,
    python,
  ],
  runtime_deps = [
    bash, # gradle is a shell script
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
      license_spdx = "Apache-2.0",
      env_state_wiring = {
        env_var = "GRADLE_USER_HOME",
        prefix = "gradle",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "gradle",
        repo = "gradle",
      },
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
