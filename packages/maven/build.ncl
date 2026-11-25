let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let bash = import "../bash/build.ncl" in
let sed = import "../sed/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "3.10.2" in
{
  name = "maven",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://archive.apache.org/dist/maven/maven-3/%{version}/binaries/apache-maven-%{version}-bin.tar.gz",
      sha256 = "8ba13121794243e604dbca50439f6ae649ce602675a167129556fd502947b249",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # mvn is a shell script
    # bin/mvn derives MAVEN_HOME with dirname (and runs uname); with a
    # .mvn/jvm.config it pipes it through tr and sed.
    coreutils,
    sed,
    jdk,
  ],
  # Not for maven's own build (that is offline): the abstract network dep a
  # package that builds WITH maven inherits, as for jbang, mvnd, curl, go and
  # uv. Resolving plugins and dependencies from Maven Central is maven's job;
  # only a fully populated local repository with -o runs offline.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    mvn = { glob = "usr/bin/mvn" } | OutputBin,
    # All Java and shell: 3.10.1 dropped 3.10.0's bundled JLine native library
    # (lib/jline-native/<OS>/<arch>/libjlinenative.so), and build.sh fails if
    # any shared object comes back, since it would need glibc and an OutputLib.
    maven_home = { glob = "usr/share/maven/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      binary_from = "https://archive.apache.org/dist/maven/",
      license_spdx = "Apache-2.0",
      # The local repository (~/.m2/repository) as a session state dir, like
      # gradle's GRADLE_USER_HOME; /usr/bin/mvn turns it into -Dmaven.repo.local.
      env_state_wiring = {
        env_var = "MAVEN_REPO_LOCAL",
        prefix = "maven",
      },
    } | Attrs,

  tests = {
    version =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "mvn --version 2>&1 | grep -q 'Apache Maven'"],
        ],
      } | Test,

    # The wrapper hands MAVEN_REPO_LOCAL to Maven. A packaging=pom project's
    # `validate` binds no plugins, so this runs offline.
    repo_local_from_state_dir =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              out=""
              trap 'echo "$out" >&2' ERR
              mkdir -p proj && cd proj
              printf '%s' '<project><modelVersion>4.0.0</modelVersion><groupId>t</groupId><artifactId>t</artifactId><version>1</version><packaging>pom</packaging></project>' > pom.xml
              out=$(MAVEN_REPO_LOCAL=/tmp/m2-state-repo mvn -o -X validate 2>&1)
              grep -qF 'BUILD SUCCESS' <<<"$out"
              grep -qF '/tmp/m2-state-repo' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
