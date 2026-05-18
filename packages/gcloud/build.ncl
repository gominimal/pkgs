let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in

let version = "568.0.0" in
# Google's per-version GCS bucket; explicit per-version path. The
# previous rapid-channel URL
# (dl.google.com/dl/cloudsdk/channels/rapid/downloads) has the
# version in the filename but is technically a release-channel
# pointer; cloud-sdk-release exposes the same content under an
# explicit storage path with stable etag metadata. Use this for
# clearer attribution + better resistance to channel rotation.
let dl_base = "https://storage.googleapis.com/cloud-sdk-release" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "ee39a260f5d30486c654be018b0e99f396a9c061617d206becaca4456e84ff94",
  arm64_sha256 = "0b31153517665f12a664675b48571938f0beeec46450485e966a4dce7b125cf6",
}
in

{
  name = "gcloud",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/google-cloud-cli-%{version}-linux-x86_64.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/google-cloud-cli-%{version}-linux-arm.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    base,
    python,
    glibc,
    subsetOf sqlite ["libs"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    gcloud = { glob = "usr/bin/gcloud" } | OutputBin,
    gsutil = { glob = "usr/bin/gsutil" } | OutputBin,
    bq = { glob = "usr/bin/bq" } | OutputBin,
    sdk = { glob = "usr/lib/google-cloud-sdk/**", allow_executable = true } | OutputData,
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/gcloud --version",

    config_ops =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "gcloud config set project test-project 2>/dev/null && gcloud config get project 2>/dev/null | grep -q 'test-project'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      # `Pixar` + `Python-2.0.1` from auto-scan were false positives:
      # `Pixar` matched a docstring in pygments' USD lexer (the file
      # itself is BSD-licensed; "Pixar" is the format it parses), and
      # `Python-2.0.1` matched a literal in packaging's SPDX-IDs
      # database file (data table, not licensed code). The
      # `Python-2.0` here is the bundled CPython interpreter's real
      # license. Tracked at pkgmgr-rs#129.
      license_spdx = "(Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND MIT AND MIT-0 AND Python-2.0)",
      env_dir_mappings = [{ read_only = false, path = "~/.config/gcloud", class = 'Credential }],
    } | Attrs,
} | BuildSpec
