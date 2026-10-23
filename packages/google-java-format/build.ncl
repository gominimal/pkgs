let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "1.37.0" in
{
  name = "google-java-format",
  # The upstream all-deps jar, run on our jdk. Upstream also publishes GraalVM
  # native-image binaries per arch; the jar is preferred because it is one
  # architecture-independent artifact (one sha256, no per-arch dispatch) and
  # runs on the same JDK as the rest of the Java tooling. Its manifest carries
  # the `Add-Exports: jdk.compiler/...` entries, so plain `java -jar` works
  # without the --add-exports flags the README lists for other launch modes.
  # Not built from source: the build is a Maven reactor that resolves its
  # dependencies from Maven Central at build time (same tradeoff as maven,
  # gradle and jdtls).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/google-java-format/releases/download/v%{version}/google-java-format-%{version}-all-deps.jar",
      sha256 = "834b2a0c38cb774953322a84b5ca3f2f40dd3156650b3cd44d3b744345962f7a",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # usr/bin/google-java-format is a /bin/sh wrapper
    jdk, # needs a full JDK (jdk.compiler module), 21+ for this release
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    google-java-format = { glob = "usr/bin/google-java-format" } | OutputBin,
    jar = { glob = "usr/share/google-java-format/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      binary_from = "https://github.com/google/google-java-format/releases/",
      source_provenance = {
        category = 'GithubRepo,
        owner = "google",
        repo = "google-java-format",
      },
    } | Attrs,

  tests = {
    # Formats a deliberately mangled class and diffs it against the exact
    # Google-style output, so a wrapper that runs but formats nothing fails.
    format =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              printf 'class Hello{void f(){int x=1;if(x>0){x++;}}}\n' > Hello.java
              printf 'class Hello {\n  void f() {\n    int x = 1;\n    if (x > 0) {\n      x++;\n    }\n  }\n}\n' > want.java
              google-java-format Hello.java > got.java
              diff -u want.java got.java
            "%
          ],
        ],
      } | Test,
    # --set-exit-if-changed is how CI uses it: non-zero on an unformatted file,
    # zero on an already-formatted one.
    check_mode =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              printf 'class Hello{}\n' > Bad.java
              printf 'class Hello {}\n' > Good.java
              if google-java-format --dry-run --set-exit-if-changed Bad.java; then
                echo "unformatted file was not reported" >&2
                exit 1
              fi
              google-java-format --dry-run --set-exit-if-changed Good.java
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
