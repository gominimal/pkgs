let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let sed = import "../sed/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

let version = "9.9.0" in
{
  name = "gradle",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://services.gradle.org/distributions/gradle-%{version}-bin.zip",
      sha256 = "0b00b0ffe07c4d4789c12d4935a44a7057d55774b7540bd4a3f76f336deb177a",
    } | Source,
    base,
    python,
  ],
  runtime_deps = [
    bash, # gradle is a shell script
    # bin/gradle (Gradle's unixStartScript) dies "xargs is not available"
    # without findutils, then pipes the JVM opts through sed and tr; uname too.
    coreutils,
    findutils,
    sed,
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
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "gradle --version 2>&1 | grep -q 'Gradle'"],
        ],
      } | Test,
  },
} | BuildSpec
