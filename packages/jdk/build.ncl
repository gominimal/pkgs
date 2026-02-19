let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "21.0.10" in
let build_num = "7" in
{
  name = "jdk",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-%{version}+%{build_num}/OpenJDK21U-jdk_x64_linux_hotspot_%{version}_%{build_num}.tar.gz",
      sha256 = "ea3b9bd464d6dd253e9a7accf59f7ccd2a36e4aa69640b7251e3370caef896a4",
    } | Source,
    base,
  ],
  runtime_deps = [
    glibc,
    gcc,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include build_num,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    jvm_libs = { glob = "usr/lib/jvm/lib/**/*.so*" } | OutputLib,
    jvm_data = { glob = "usr/lib/jvm/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "adoptium",
        repo = "temurin21-binaries",
      },
    } | Attrs,

  tests = {
    java_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "java -version 2>&1 | grep -q '21'"],
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
