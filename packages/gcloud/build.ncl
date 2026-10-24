let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let python = import "../python/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in

let version = "590.0.1" in
# Google's per-version GCS bucket; explicit per-version path. The
# previous rapid-channel URL
# (dl.google.com/dl/cloudsdk/channels/rapid/downloads) has the
# version in the filename but is technically a release-channel
# pointer; cloud-sdk-release exposes the same content under an
# explicit storage path with stable etag metadata. Use this for
# clearer attribution + better resistance to channel rotation.
let dl_base = "https://storage.googleapis.com/cloud-sdk-release" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "d1ae7be7e12c4e7d8286fab4774f5441020aca89dc7793ddacbace8d11d20f06",
  arm64_sha256 = "fd760d8b1c2c4c484d7b659964994b07aaefddc6ac4350e681940477dbdbb22c",
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
    # The SDK's installation properties point core/custom_ca_certs_file at this
    # package's /etc/ssl/certs/ca-certificates.crt (see build.sh, CVE-2026-111943),
    # and gcloud rejects that property when the file does not exist.
    ca-certificates,
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

    # CVE-2026-111943: the SDK's vendored CA bundles still trust emSign ECC Root
    # CA - G3, so build.sh points core/custom_ca_certs_file at the system store
    # in the installation properties. Offline: checks that a user with no config
    # of their own resolves the property to the system bundle, that the bundle
    # is there, and that gsutil's and bq's bootstraps still forward it.
    ca_certs_from_system_store =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "export CLOUDSDK_CONFIG=$(mktemp -d) && test \"$(gcloud config get core/custom_ca_certs_file 2>/dev/null)\" = /etc/ssl/certs/ca-certificates.crt"],
          ["/bin/bash", "-c", "test -s /etc/ssl/certs/ca-certificates.crt"],
          ["/bin/bash", "-c", "grep -q 'properties.VALUES.core.custom_ca_certs_file' /usr/lib/google-cloud-sdk/bin/bootstrapping/gsutil.py && grep -q 'properties.VALUES.core.custom_ca_certs_file' /usr/lib/google-cloud-sdk/bin/bootstrapping/bq.py"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      binary_from = "https://storage.googleapis.com/cloud-sdk-release",
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
