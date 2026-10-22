let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let sed = import "../sed/build.ncl" in

let version = "4.10.5" in
{
  name = "spotbugs",
  # The upstream binary distribution (bin/ launchers, lib/ jars), run on our
  # jdk. Not built from source: the build is Gradle, which resolves its
  # dependencies from Maven Central at build time (same tradeoff as maven,
  # gradle and jdtls).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/spotbugs/spotbugs/releases/download/%{version}/spotbugs-%{version}.tgz",
      sha256 = "cce3244900cc215ccd9f5a8db29ed9468fc47824faf662f4fad005343d96007e",
    } | Source,
    base,
  ],
  runtime_deps = [
    # bin/spotbugs is a POSIX sh script that calls ls, expr, dirname, uname
    # and sed before it execs java.
    bash,
    coreutils,
    sed,
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    spotbugs = { glob = "usr/bin/spotbugs" } | OutputBin,
    # allow_executable: the tree carries upstream's bin/ launcher scripts.
    spotbugs_home = { glob = "usr/share/spotbugs/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # LICENSE.txt is the LGPL-2.1 text; the source headers say "either
      # version 2.1 of the License, or (at your option) any later version".
      # lib/ also bundles Apache-2.0 / BSD / MPL jars (LICENSE-*.txt).
      license_spdx = "LGPL-2.1-or-later",
      binary_from = "https://github.com/spotbugs/spotbugs/releases/",
      source_provenance = {
        category = 'GithubRepo,
        owner = "spotbugs",
        repo = "spotbugs",
      },
    } | Attrs,

  tests = {
    # SpotBugs analyses bytecode, so compile a class with a textbook
    # high-priority correctness bug (unconditional self-recursion) and require
    # the IL_INFINITE_RECURSIVE_LOOP finding; a clean class must report none.
    find_bug =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              mkdir -p bad good
              printf 'public class Bad {\n  public int loop(int x) {\n    return loop(x);\n  }\n}\n' > Bad.java
              printf 'public class Good {\n  public int twice(int x) {\n    return x * 2;\n  }\n}\n' > Good.java
              javac -d bad Bad.java
              javac -d good Good.java
              spotbugs -textui -low -xml:withMessages -output bad.xml bad
              grep -q 'type="IL_INFINITE_RECURSIVE_LOOP"' bad.xml || { cat bad.xml >&2; exit 1; }
              spotbugs -textui -low -xml:withMessages -output good.xml good
              grep -q '<BugCollection' good.xml || { cat good.xml >&2; exit 1; }
              if grep -q '<BugInstance' good.xml; then
                cat good.xml >&2
                echo "clean class was flagged" >&2
                exit 1
              fi
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
