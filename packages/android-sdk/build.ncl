let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in

let version = "16111833" in
{
  name = "android-sdk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://dl.google.com/android/repository/commandlinetools-linux-%{version}_latest.zip",
      sha256 = "0877a1d048fe4a24efe2eff536ca4223f7adeb58648bb81909d33c446918cfa8",
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
