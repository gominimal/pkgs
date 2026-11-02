let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let sed = import "../sed/build.ncl" in
let unzip = import "../unzip/build.ncl" in

let version = "7.28.0" in
{
  name = "pmd",
  # The upstream binary distribution (pmd-dist-<v>-bin.zip: the bin/pmd
  # launcher, conf/ and ~115 jars), run on our jdk. Not built from source: the
  # build is a Maven reactor that resolves its dependencies from Maven Central
  # at build time (same tradeoff as maven, gradle and jdtls).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pmd/pmd/releases/download/pmd_releases/%{version}/pmd-dist-%{version}-bin.zip",
      sha256 = "f974ba571f7bc01c73fffe11bade25fbc1f438698f9e9c00e416e8d65e9fbac2",
    } | Source,
    base,
    unzip,
  ],
  runtime_deps = [
    # bin/pmd is a POSIX sh script that calls uname, dirname, grep and sed
    # (to parse `java -XshowSettings:properties`) before it execs java.
    bash,
    coreutils,
    grep,
    sed,
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    pmd = { glob = "usr/bin/pmd" } | OutputBin,
    # allow_executable: the tree carries upstream's bin/pmd launcher.
    pmd_home = { glob = "usr/share/pmd/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # LICENSE is PMD's own BSD-style text (InfoEther, LLC) followed by the
      # Apache-2.0 text that covers newer parts. The BSD-style part adds an
      # end-user-documentation acknowledgement clause ("This product includes
      # software developed in part by support from the Defense Advanced
      # Research Project Agency (DARPA)"), so it is neither BSD-3-Clause nor
      # BSD-4-Clause (whose extra clause is about advertising materials), and
      # SPDX has no identifier for it: a LicenseRef per repo convention (cf.
      # LicenseRef-BuDDy).
      license_spdx = "LicenseRef-PMD AND Apache-2.0",
      binary_from = "https://github.com/pmd/pmd/releases/",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pmd",
        repo = "pmd",
      },
    } | Attrs,

  tests = {
    # The quickstart ruleset must report the planted problems with PMD's
    # "violations found" exit code (4), and must pass a clean file (0). The clean
    # file declares a package because quickstart includes NoPackage.
    check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -u
              mkdir -p bad good
              printf 'class Foo {\n  private int unused;\n  void f() {\n    try {\n      g();\n    } catch (Exception e) {\n    }\n  }\n  void g() throws Exception {}\n}\n' > bad/Foo.java
              printf 'package demo;\n\nclass Bar {\n  int twice(int x) {\n    return x * 2;\n  }\n}\n' > good/Bar.java
              pmd check --no-progress -d bad -R rulesets/java/quickstart.xml -f text > bad.out 2>&1
              rc=$?
              cat bad.out
              [ "$rc" -eq 4 ] || { echo "expected exit 4 (violations), got $rc" >&2; exit 1; }
              grep -q 'UnusedPrivateField' bad.out || exit 1
              grep -q 'EmptyCatchBlock' bad.out || exit 1
              pmd check --no-progress -d good -R rulesets/java/quickstart.xml -f text > good.out 2>&1
              rc=$?
              cat good.out
              [ "$rc" -eq 0 ] || { echo "expected exit 0 on a clean file, got $rc" >&2; exit 1; }
            "%
          ],
        ],
      } | Test,
    # CPD, the copy-paste detector that ships in the same distribution.
    cpd =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -u
              mkdir -p src
              body='  int calc(int a, int b) {\n    int s = 0;\n    for (int i = 0; i < a; i++) {\n      s += i * b;\n      if (s > 100) {\n        s -= 7;\n      }\n    }\n    return s;\n  }\n'
              printf "class A {\n${body}}\n" > src/A.java
              printf "class B {\n${body}}\n" > src/B.java
              pmd cpd --minimum-tokens 20 --language java -d src > cpd.out 2>&1
              rc=$?
              cat cpd.out
              [ "$rc" -eq 4 ] || { echo "expected exit 4 (duplication), got $rc" >&2; exit 1; }
              grep -q 'Found a .*duplication' cpd.out || exit 1
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
