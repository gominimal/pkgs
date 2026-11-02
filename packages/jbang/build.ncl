let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "0.143.0" in
{
  name = "jbang",
  # JBang runs single-file Java programs (`jbang hello.java`), resolving any
  # `//DEPS` from Maven Central. The platform-independent bundle is a bash
  # launcher plus one jar.
  #
  # Prebuilt, not built from source: jbang builds with Gradle and resolves its
  # dependencies from Maven Central, so a hermetic source build is not possible
  # today. Same shape as maven / gradle / jdtls.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jbangdev/jbang/releases/download/v%{version}/jbang-%{version}.tar",
      sha256 = "1388fcc2258e2bdcd277c68a5aad5a9d7c1dc8b57ef06165a45da02c2ed9775b",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # bin/jbang is a bash script (#!/usr/bin/env bash, BASH_SOURCE, [[ ]])
    coreutils, # env, uname, dirname, readlink in the launcher
    jdk, # the wrapper pins JAVA_HOME here so jbang never downloads a JDK
  ],
  # Not for jbang's own build (that is offline): this is the abstract network
  # dep a package that builds WITH jbang inherits. jbang's job is resolving
  # `//DEPS` from Maven Central (and, for `//JAVA <n>` other than the packaged
  # jdk, downloading a JDK), like curl/go/pnpm/uv. A script with no `//DEPS`
  # runs fully offline; see the run_script test.
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
    jbang = { glob = "usr/bin/jbang" } | OutputBin,
    launcher = { glob = "usr/share/jbang/bin/jbang" } | OutputBin,
    jbang_home = { glob = "usr/share/jbang/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      binary_from = "https://github.com/jbangdev/jbang/releases",
      # jbang keeps its script cache, compiled jars and any downloaded JDKs in
      # JBANG_DIR (default ~/.jbang, which a session may not be able to write).
      env_state_wiring = {
        env_var = "JBANG_DIR",
        prefix = "jbang",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "jbangdev",
        repo = "jbang",
      },
    } | Attrs,

  tests = {
    jbang_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "jbang --version 2>&1 | grep -qF '%{version}'"],
        ],
      } | Test,

    # Compile and run a self-contained script with --offline, so any attempt to
    # reach the network (dependency resolution, JDK download) fails the test
    # instead of passing silently. JBANG_DIR keeps jbang's cache in the test's
    # cwd rather than ~/.jbang.
    run_script =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf 'class hello {\\n  public static void main(String[] args) {\\n    System.out.println(\"hello \" + String.join(\",\", args));\\n  }\\n}\\n' > hello.java"],
          ["/bin/bash", "-c", "JBANG_DIR=\"$PWD/jbang-home\" jbang --offline hello.java a b > out.txt"],
          ["/bin/bash", "-c", "grep -qx 'hello a,b' out.txt"],
        ],
      } | Test,
  },
} | BuildSpec
