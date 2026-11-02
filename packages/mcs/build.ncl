let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "0.11.2" in
{
  name = "mcs",
  # mcs searches the Maven Central Repository from the command line
  # (`mcs search <term>`, `mcs class-search <Class>`).
  #
  # The upstream pure-JVM jar, run on our jdk. Upstream's GraalVM native
  # binaries exist only for linux-x86_64 (no arm64), so the jar is the one
  # artifact that covers both arches: one sha256, no per-arch dispatch. It is
  # self-contained (picocli, dagger and jackson are shaded in) and needs Java 25
  # (class file version 69).
  #
  # Prebuilt, not built from source: the build is Maven (via the Maven Wrapper)
  # resolving from Maven Central. Same tradeoff as maven / gradle / jdtls.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/mthmulders/mcs/releases/download/v%{version}/mcs-%{version}.jar",
      sha256 = "ac99d2015ac40ec46b678ea36a1a89d3b01bec8bd641d03b79ff8609a0bf3ad0",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # usr/bin/mcs is a /bin/sh wrapper
    jdk, # Java 25+ (class file version 69)
  ],
  # Not for mcs's own build (that is offline): this is the abstract network
  # dep a consumer inherits. Every search queries search.maven.org (and
  # `--show-vulnerabilities` queries Sonatype OSS Index), like jbang/curl/uv.
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
    mcs = { glob = "usr/bin/mcs" } | OutputBin,
    jar = { glob = "usr/share/mcs/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      binary_from = "https://github.com/mthmulders/mcs/releases",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mthmulders",
        repo = "mcs",
      },
    } | Attrs,

  tests = {
    # Not named `version`: that would shadow %{version} inside the tests block.
    mcs_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "mcs --version > out.txt 2>&1; grep -qx 'mcs v%{version}' out.txt"],
        ],
      } | Test,

    # picocli help for the top level and the search subcommand.
    help =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              mcs --help > top.txt
              grep -qE '^  search +Search artifacts in Maven Central by coordinates' top.txt
              grep -qE '^  class-search +Search artifacts in Maven Central by class name' top.txt
              mcs search --help > search.txt
              grep -qF 'gradle-kotlin' search.txt
            "%
          ],
        ],
      } | Test,

    # Every mcs search goes to the network, so there is no offline success
    # path to test. Instead, pin HTTP(S)_PROXY to a closed local port (mcs
    # honours both): the search must run the whole query path (dagger wiring,
    # HTTP client, error reporting) on our jdk and fail closed, without
    # reaching Maven Central or printing results.
    offline_fails_closed =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -u
              HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 mcs search junit:junit > out.txt 2>&1
              rc=$?
              cat out.txt
              test "$rc" -ne 0
              grep -qF 'Searching for junit:junit...' out.txt
              grep -qF 'MCS ran into an error' out.txt
              ! grep -qF 'Found ' out.txt
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
