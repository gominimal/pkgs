let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in

let version = "559.0.0" in
let dl_base = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "e80517d8f1d690ade1920b600db2594cb5f18e0a61cb5c579f60a9fd8112cc1f",
  arm64_sha256 = "02a91349f72c35d65ba33b5dd7d1ccf44fa2c40a358207c50017465ab9eea5cd",
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
          ["/bin/bash", "-c", "gcloud config set project test-project 2>&1"],
          ["/bin/bash", "-c", "gcloud config get project 2>&1 | grep -q 'test-project'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      env_dir_mappings = [{ read_only = false, path = "~/.config/gcloud", class = 'Credential }],
    } | Attrs,
} | BuildSpec
