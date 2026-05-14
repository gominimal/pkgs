let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in

let version = "568.0.0" in
# Google's immutable per-version GCS bucket. The previous rapid-
# channel URL (`dl.google.com/dl/cloudsdk/channels/rapid/downloads`)
# serves moving content under the same filename — bytes that hash
# to one SHA today can hash to a different SHA tomorrow when Google
# republishes a build fix. cloud-sdk-release is content-stable
# (verified via `last-modified` + `etag` headers); each upload
# pins the version forever.
let dl_base = "https://storage.googleapis.com/cloud-sdk-release" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "b788b7f752b49f802c0682ba7f2e3d37f20fca73e67fad354deb70186b2838b8",
  arm64_sha256 = "632a0bf414670b991e06385fc4b8d393e9c6a1968ae3852c608a277809ceb985",
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
      license_spdx = "(Apache-2.0 AND BSD-2-Clause AND BSD-3-Clause AND MIT AND MIT-0 AND Pixar AND Python-2.0.1)",
      env_dir_mappings = [{ read_only = false, path = "~/.config/gcloud", class = 'Credential }],
    } | Attrs,
} | BuildSpec
