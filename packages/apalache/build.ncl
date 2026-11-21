# Apalache, the symbolic model checker for TLA+ and Quint (the backend of
# `quint verify`, and the jar `quint verify --backend tlc` runs TLC from).
#
# Upstream's release distribution, not a source build (AGENTS.md "JVM tools are
# such a case for now"): Apalache is Scala built with sbt, which resolves its
# whole dependency graph from Maven Central at build time, and nothing stages
# that for an offline build yet (#969). The artifact is one fat jar
# (lib/apalache.jar, every dependency shaded in, Main-Class set, class files at
# most Java 21) plus a bash launcher. It runs offline and never downloads code.
#
# Native code inside the jar (justified separately, per AGENTS.md): the JVM
# extracts these to java.io.tmpdir and loads them at run time.
#  - z3 4.14.1 (z3-turnkey: libz3.so + libz3java.so for linux amd64 and
#    aarch64). Apalache's SMT backend. Our `z3` package can't stand in: the
#    jar's com.microsoft.z3 Java classes are the 4.14.1 bindings and call
#    libz3java's JNI entry points, which are generated per z3 release, and
#    z3-turnkey only loads the copies inside the jar. Needs GLIBC_2.34,
#    GLIBCXX_3.4.30, libstdc++ and libgcc_s, hence the gcc-runtime subset below.
#  - cvc5 JNI (an optional alternative solver) and zstd-jni, same story;
#    neither needs more than the z3 libraries do.
#
# Mirror of the release asset apalache-%{version}.tgz, sha256 checked against
# the release's sha256sum.txt and GitHub's asset digest:
# https://github.com/apalache-mc/apalache/releases/download/v0.62.4/apalache-0.62.4.tgz
#
# The version is the one quint pins (DEFAULT_APALACHE_VERSION_TAG in quint
# 0.33.1's dist/src/apalache.js), so `quint verify` can use this install.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "0.62.4" in
{
  name = "apalache",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/apalache-mc/apalache/apalache-%{version}.tgz",
      sha256 = "b781b53bba32fac14ac2e02b0332e1dc2edc64cb7b850c0608d8142cc7aa2ef4",
      extract = false,
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # the launcher is `#!/usr/bin/env bash`
    coreutils, # env, dirname, readlink, mktemp in the launcher
    # The launcher runs /usr/lib/jvm/bin/java (build.sh pins it). Any Java 21+
    # runs the jar; `jdk` is the current LTS.
    jdk,
    # z3 / cvc5 JNI libraries extracted from the jar at run time.
    glibc,
    subsetOf gcc-runtime ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    apalache-mc = { glob = "usr/bin/apalache-mc" } | OutputBin,
    dist = { glob = "usr/lib/apalache/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # Apalache's own code. The fat jar also bundles (license texts in the
      # jar's root and META-INF/):
      #  - Apache-2.0: Scala library, Guava, Guice, gRPC, Netty, Jackson,
      #    commons-*; BSD-3-Clause: protobuf-java; MIT: tla2tools (TLC, SANY),
      #    z3, checker-qual; BSD-2-Clause: zstd-jni.
      #  - cvc5 JNI: BSD-3-Clause, built without GPL libraries
      #    (Configuration::licenseIsGpl() returns false) but statically linking
      #    GMP (LGPL-3.0).
      #  - weak copyleft: Eclipse Jetty, lsp4j, xtext (EPL-2.0, dual-licensed
      #    for Jetty/lsp4j); jakarta.servlet (EPL-2.0 OR GPL-2.0 WITH
      #    Classpath-exception-2.0); logback (EPL-1.0 OR LGPL-2.1); kiama
      #    (MPL-2.0); javax.mail / javax.activation via tla2tools (CDDL-1.1 OR
      #    GPL-2.0 WITH Classpath-exception-2.0).
      # All redistributable unmodified as shipped; nothing is GPL-only.
      license_spdx = "Apache-2.0",
      binary_from = "https://github.com/apalache-mc/apalache/releases",
      source_provenance = {
        category = 'GithubRepo,
        owner = "apalache-mc",
        repo = "apalache",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "set -eu; out=$(JVM_ARGS=-Xmx1g apalache-mc version 2>&1); echo \"$out\"; grep -qx '%{version}' <<< \"$out\""],
        ],
      } | Test,
    # A bounded model check through the z3 backend, on the packaged jdk even with a
    # failing `java` first on PATH: an invariant that holds must pass (NoError, exit 0), and
    # a violated one must fail (Error, exit 12) with a counterexample, so a
    # checker that checks nothing can't pass.
    check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              # a `java` first on PATH that fails: the launcher must not run it
              mkdir -p fakebin
              printf '#!/bin/sh\necho "PATH java ran" >&2\nexit 99\n' > fakebin/java
              chmod +x fakebin/java
              export PATH="$PWD/fakebin:$PATH" JVM_ARGS=-Xmx1g HOME="$PWD/home" TMPDIR="$PWD/tmp"
              mkdir -p "$HOME" "$TMPDIR"
              cat > Counter.tla <<'EOF'
              ---- MODULE Counter ----
              EXTENDS Integers
              VARIABLE
                \* @type: Int;
                x
              Init == x = 0
              Next == x' = x + 1
              NonNegative == x >= 0
              BelowThree == x < 3
              ====
              EOF
              apalache-mc check --length=5 --inv=NonNegative Counter.tla > ok.log 2>&1 || { cat ok.log; exit 1; }
              cat ok.log
              grep -q 'The outcome is: NoError' ok.log
              rc=0
              apalache-mc check --length=5 --inv=BelowThree Counter.tla > bad.log 2>&1 || rc=$?
              cat bad.log
              [ "$rc" = 12 ] || { echo "violated invariant: expected exit 12, got $rc" >&2; exit 1; }
              grep -q 'The outcome is: Error' bad.log
              grep -q 'state invariant 0 violated' bad.log
              grep -q 'Check the trace in: .*violation1.tla' bad.log
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
