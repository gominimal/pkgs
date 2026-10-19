let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "27" in
let build_num = "35" in
let dl_base = "https://github.com/adoptium/temurin27-binaries/releases/download/jdk-%{version}+%{build_num}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "1cf69a4848ffb728b3b260dfd45206a51566ab571a02a30092271d4c580bccbc",
  arm64_sha256 = "e4ec5c7276290c7bde0baecba9a29be4962f5388684296406a9799d465936087",
}
in

# Eclipse Temurin 27, the current Java feature release (non-LTS; Adoptium's
# prebuilt OpenJDK binaries). Its own package, separate from `jdk` (the LTS
# line), so projects opt into the newest language/JVM features explicitly.
# Non-LTS: superseded by JDK 28 in March 2027. A GA release has no dotted
# version: tag `jdk-27+35`, assets `..._27_35.tar.gz`, top dir `jdk-27+35`.
# Same layout and outputs as packages/jdk.
{
  name = "jdk-27",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/OpenJDK27U-jdk_x64_linux_hotspot_%{version}_%{build_num}.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/OpenJDK27U-jdk_aarch64_linux_hotspot_%{version}_%{build_num}.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    alsa-lib,
    glibc,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include build_num,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    jvm_bins = { glob = "usr/lib/jvm/bin/*" } | OutputBin,
    jvm_libs = { glob = "usr/lib/jvm/lib/**/*.so*" } | OutputLib,
    jvm_libdata = { glob = "usr/lib/jvm/lib/**", allow_executable = true } | OutputData,

    jvm_data = { glob = "usr/lib/jvm/{jmod,conf,legal}/**" } | OutputData,
    jvm_includes = { glob = "usr/lib/jvm/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "adoptium",
        repo = "temurin27-binaries",
      },
    } | Attrs,

  tests = {
    java_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "java -version 2>&1 | grep -q 'version \"27'"],
        ],
      } | Test,

    javac_compile =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'public class Hi { public static void main(String[] a) { System.out.println(\"ok\"); } }' > Hi.java"],
          ["/bin/javac", "Hi.java"],
          ["/bin/bash", "-c", "java Hi | grep -q '^ok$'"],
        ],
      } | Test,
  },
} | BuildSpec
