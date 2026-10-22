let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "1.0.6" in
# The Maven that mvnd 1.0.6 embeds (mvn/lib/maven-core-<v>.jar). It is NOT our
# `maven` package and moves only when mvnd releases; build.sh fails closed if
# the tarball disagrees, and the tests assert it.
let maven_version = "3.9.16" in
let dl_base = "https://github.com/apache/maven-mvnd/releases/download/%{version}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "88fd474fd3f21b33ec1e6a75950f6abbe493d63a5e2b429475f5230b3ee6cb24",
  arm64_sha256 = "e1d8071e172740ecd6a9c380938de69aafc7622218818c56e4d526cc761723c0",
}
in

{
  name = "mvnd",
  # Apache Maven Daemon: a GraalVM native-image client (bin/mvnd) that hands
  # builds to a long-lived daemon JVM running an embedded Maven.
  #
  # Prebuilt, not built from source: the client is a GraalVM native image and
  # we have no GraalVM / native-image package; the daemon side builds with
  # Maven from Maven Central. Per-arch upstream tarballs, like packages/jdk.
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/maven-mvnd-%{version}-linux-amd64.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/maven-mvnd-%{version}-linux-aarch64.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    bash, # /usr/bin/mvnd wrapper, bin/mvnd.sh and the embedded Maven's scripts
    glibc, # native client: libc, libdl, libpthread, librt (+ ld-linux-aarch64 on arm64)
    jdk, # the daemon is a JVM process; the wrapper defaults JAVA_HOME here
  ],
  # Not for mvnd's own build (that is offline): the abstract network dep a
  # package that builds WITH mvnd inherits, as for jbang, maven, curl, go and
  # uv. Resolving plugins and dependencies from Maven Central is mvnd's job;
  # only a fully populated local repository with -o runs offline.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
    include maven_version,
  },

  outputs = {
    mvnd = { glob = "usr/bin/mvnd" } | OutputBin,
    client = { glob = "usr/share/mvnd/bin/{mvnd,mvnd.sh}" } | OutputBin,
    mvnd_home = { glob = "usr/share/mvnd/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      binary_from = "https://github.com/apache/maven-mvnd/releases",
      # Daemon registry and logs (default ~/.m2/mvnd) as a session state dir,
      # like gradle's GRADLE_USER_HOME. The native client reads
      # MVND_DAEMON_STORAGE directly. The local repository is maven's
      # MAVEN_REPO_LOCAL, which the wrapper forwards (build.sh).
      env_state_wiring = {
        env_var = "MVND_DAEMON_STORAGE",
        prefix = "mvnd",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "apache",
        repo = "maven-mvnd",
      },
    } | Attrs,

  # Each test keeps daemon state and the local repository in its own cwd
  # (HOME may not be writable) and stops the daemon at the end, so no JVM
  # outlives the test. They set MVND_DAEMON_STORAGE and MAVEN_REPO_LOCAL,
  # the two variables a session wires, so they also exercise the client's
  # env binding and the wrapper's forwarding.
  tests = {
    # --version goes through the daemon: the client prints its own version,
    # then starts a daemon JVM that reports the embedded Maven.
    mvnd_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "export MVND_DAEMON_STORAGE=\"$PWD/mvnd\" MAVEN_REPO_LOCAL=\"$PWD/repo\"; mvnd -B --version > out.txt 2>&1; rc=$?; mvnd --stop >/dev/null 2>&1; exit $rc"],
          ["/bin/bash", "-c", "grep -qF 'mvnd) %{version}' out.txt"],
          ["/bin/bash", "-c", "grep -qF 'Apache Maven %{maven_version}' out.txt"],
        ],
      } | Test,

    # A real build through the daemon, offline (-o): a packaging=pom project's
    # `validate` phase binds no plugins, so nothing needs Maven Central.
    # Anything that does (a compile, a test run) needs network; see the PR.
    offline_validate =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf '<project xmlns=\"http://maven.apache.org/POM/4.0.0\">\\n  <modelVersion>4.0.0</modelVersion>\\n  <groupId>dev.minimal</groupId>\\n  <artifactId>smoke</artifactId>\\n  <version>1</version>\\n  <packaging>pom</packaging>\\n</project>\\n' > pom.xml"],
          ["/bin/bash", "-c", "export MVND_DAEMON_STORAGE=\"$PWD/mvnd\" MAVEN_REPO_LOCAL=\"$PWD/repo\"; mvnd -B -o -X validate > out.txt 2>&1; rc=$?; mvnd --stop >/dev/null 2>&1; exit $rc"],
          ["/bin/bash", "-c", "grep -qF 'BUILD SUCCESS' out.txt || { cat out.txt; exit 1; }"],
          # The daemon used the wired storage and the forwarded repository.
          ["/bin/bash", "-c", "ls \"$PWD/mvnd\"/*/registry.bin >/dev/null 2>&1 || ls \"$PWD/mvnd\"/registry.bin >/dev/null 2>&1 || { ls -R \"$PWD/mvnd\"; exit 1; }"],
          ["/bin/bash", "-c", "grep -qF \"$PWD/repo\" out.txt || { grep -i 'local repository' out.txt; exit 1; }"],
        ],
      } | Test,
  },
} | BuildSpec
