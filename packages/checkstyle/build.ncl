let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "14.3.0" in
{
  name = "checkstyle",
  # The upstream `-all.jar` (checkstyle plus its dependencies, Main-Class set),
  # run on our jdk. It bundles google_checks.xml and sun_checks.xml as
  # classpath resources, so `checkstyle -c /google_checks.xml` works with no
  # extra files. Not built from source: the build is a Maven reactor that
  # resolves its dependencies from Maven Central at build time (same tradeoff
  # as maven, gradle and jdtls).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-%{version}/checkstyle-%{version}-all.jar",
      sha256 = "754e218ab1fcabb1e1c5f8530e9d3aa37636806c22987bb279dd907a6ee749b2",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # usr/bin/checkstyle is a /bin/sh wrapper
    jdk, # 14.x is built for Java 21 (class file version 65)
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    checkstyle = { glob = "usr/bin/checkstyle" } | OutputBin,
    jar = { glob = "usr/share/checkstyle/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # Source headers: "either version 2.1 of the License, or (at your
      # option) any later version".
      license_spdx = "LGPL-2.1-or-later",
      binary_from = "https://github.com/checkstyle/checkstyle/releases/",
      source_provenance = {
        category = 'GithubRepo,
        owner = "checkstyle",
        repo = "checkstyle",
      },
    } | Attrs,

  tests = {
    # google_checks.xml (bundled, severity=warning): a lower-case class name
    # must be reported by TypeName, and a conforming file (which needs a package
    # declaration matching its directory, since PackageDeclaration is in the set)
    # must report nothing.
    google_checks =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              printf 'class bad_name {}\n' > bad_name.java
              mkdir -p demo
              printf 'package demo;\n\nclass Good {}\n' > demo/Good.java
              checkstyle -c /google_checks.xml bad_name.java > bad.out 2>&1 || true
              cat bad.out
              grep -q '\[WARN\].*bad_name.java.*\[TypeName\]' bad.out
              checkstyle -c /google_checks.xml demo/Good.java > good.out 2>&1
              cat good.out
              grep -q 'Audit done' good.out
              if grep -q '\[WARN\]' good.out; then
                echo "conforming file was flagged" >&2
                exit 1
              fi
            "%
          ],
        ],
      } | Test,
    # sun_checks.xml has severity=error, and checkstyle exits with the error
    # count, so a violating file must fail the run.
    exit_code =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              printf 'class bad_name {}\n' > bad_name.java
              if checkstyle -c /sun_checks.xml bad_name.java > sun.out 2>&1; then
                cat sun.out
                echo "sun_checks violations did not fail the run" >&2
                exit 1
              fi
              grep -q '\[ERROR\].*\[TypeName\]' sun.out
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
