let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let unzip = import "../unzip/build.ncl" in

let version = "2.4.21" in
{
  name = "kotlin",
  # Kotlin compiler (kotlinc) and runner. Upstream's kotlin-compiler zip is
  # pure JVM (bash launchers + jars), so it is architecture-independent.
  #
  # Prebuilt, not built from source: the compiler builds with Gradle and
  # bootstraps from an earlier Kotlin release, resolving several hundred
  # artifacts from Maven Central / JetBrains repositories, so a hermetic
  # source build is not possible today. Same shape as maven / gradle / jdtls.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/JetBrains/kotlin/releases/download/v%{version}/kotlin-compiler-%{version}.zip",
      sha256 = "7cc140e76daf416a0424a5557f99afd7ca89ebd463ea1101261e3e01c33e75cd",
    } | Source,
    base,
    unzip,
  ],
  runtime_deps = [
    bash, # the launchers are bash scripts (#!/usr/bin/env bash, BASH_SOURCE, [[ =~ ]])
    coreutils, # env, uname, dirname, readlink, basename in the launchers
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    launchers = { glob = "usr/share/kotlin/bin/*" } | OutputBin,
    kotlin_home = { glob = "usr/share/kotlin/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      binary_from = "https://github.com/JetBrains/kotlin/releases",
      source_provenance = {
        category = 'GithubRepo,
        owner = "JetBrains",
        repo = "kotlin",
      },
    } | Attrs,

  tests = {
    kotlinc_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "kotlinc -version 2>&1 | grep -qF 'kotlinc-jvm %{version}'"],
        ],
      } | Test,

    # Compile a program, bundle the stdlib, and run the jar on the plain JVM.
    # Fully offline: the stdlib comes from the distribution's lib/.
    compile_and_run =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf 'fun main() {\\n    val xs = listOf(1, 2, 3)\\n    println(\"sum=${xs.sum()}\")\\n}\\n' > hello.kt"],
          ["/bin/bash", "-c", "kotlinc hello.kt -include-runtime -d hello.jar"],
          ["/bin/bash", "-c", "java -jar hello.jar | grep -qx 'sum=6'"],
        ],
      } | Test,
  },
} | BuildSpec
