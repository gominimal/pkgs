let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# not the `jdk` meta-package: the inputs of build.sh's CVE-2026-111943 step
let jdk = import "../jdk/cve-2026-111943.ncl" in

let version = "21.0.13" in
let build_num = "9" in
let dl_base = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-%{version}+%{build_num}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "d7f5d5cf865a2902b70ff549b97586a7d3f234e016f041ab447ea740c7d66d1c",
  arm64_sha256 = "e3522e707fc7dbe2a72c30746b1e7068301a0213ecd213d4491f35a14eb55578",
}
in

# Eclipse Temurin 21, the previous Java LTS. This was `jdk` until `jdk`
# became the current LTS (jdk-25); kept for projects pinned to 21.
{
  name = "jdk-21",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/OpenJDK21U-jdk_x64_linux_hotspot_%{version}_%{build_num}.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/OpenJDK21U-jdk_aarch64_linux_hotspot_%{version}_%{build_num}.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
    jdk.script,
    jdk.program,
    jdk.fixtures,
    jdk.blocked_sha256,
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

    # CVE-2026-111943: the shipped trust store no longer holds emSign ECC Root CA - G3 or
    # AAA Certificate Services, still holds the rest, and blocked.certs lists the compromised
    # intermediates (one ECDSA-malleated encoding checked; the build checks all 48).
    cve_2026_111943 =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -eu; ks=$(keytool -list -cacerts -storepass changeit -v 2>&1); n=$(grep -c '^Alias name:' <<< \"$ks\"); echo \"cacerts entries: $n\"; [ \"$n\" -ge 80 ]; if grep -E 'SHA256: (86:A1:EC:BA:08:9C:4A:8D|D7:A7:A0:FB:5D:7E:27:31)' <<< \"$ks\"; then echo 'distrusted root still in cacerts'; exit 1; fi; bc=/usr/lib/jvm/lib/security/blocked.certs; head -n 1 $bc | grep -qx 'Algorithm=SHA-256'; grep -qx 37E866582D43C35D7C17D47794B974F291B3047B868DC123382477F7A08AEFA8 $bc"],
        ],
      } | Test,
  },
} | BuildSpec
