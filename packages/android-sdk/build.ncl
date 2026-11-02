let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

# cmdline-tools 22.0 (build 15859902), the last line with the Java sdkmanager.
# 23.0 (16111833) removed it: `sdkmanager` became a shim over a native
# `android` CLI that Google ships for x86-64 only (one Linux zip, no arm64),
# so on arm64 there is no SDK manager at all (gominimal/pkgs#1152). Decline
# auto-updates to 23.0+ until that changes or we decide to ship the native CLI.
let version = "15859902" in
{
  name = "android-sdk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://dl.google.com/android/repository/commandlinetools-linux-%{version}_latest.zip",
      sha256 = "4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583",
    } | Source,
    base,
    jdk,
    python,
  ],
  runtime_deps = [
    jdk,
    base,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    sdkmanager = { glob = "usr/bin/sdkmanager" } | OutputBin,
    sdk = { glob = "usr/lib/android-sdk/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LicenseRef-Android-SDK-Terms",
      # Android SDK License Agreement §3.4: "you may not copy (except for
      # backup purposes), modify, adapt, redistribute ... the SDK or any part
      # of the SDK." (§3.5: bundled open-source parts keep their own licenses.)
      redistributable = false,
      binary_from = "https://dl.google.com/android/repository/",
    } | Attrs,

  tests = {
    sdkmanager_version =
      {
        class = 'Standalone,
        test_deps = [base, jdk],
        cmds = [
          ["/bin/bash", "-c", "sdkmanager --version"],
        ],
      } | Test,
  },
} | BuildSpec
