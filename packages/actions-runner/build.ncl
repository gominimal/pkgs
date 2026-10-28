let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let icu = import "../icu/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let openssl-3-5 = import "../openssl-3.5/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.336.0" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d",
  arm64_sha256 = "58b758e420b87093fbd4bfddd368074960053e2f1388f01848c82624b90f27d1",
}
in

{
  name = "actions-runner",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-staging-archives/actions/runner/actions-runner-linux-x64-%{version}.tar.gz",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-staging-archives/actions/runner/actions-runner-linux-arm64-%{version}.tar.gz",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    bash,
    glibc,
    icu,
    openssl,
    # The bundled .NET 8 runtime (sdk 8.0.422 at 2.336.0) dlopens libssl.so.3 /
    # libcrypto.so.3 and does not know OpenSSL 4's .so.4 names; only .NET 10 got that
    # loader (dotnet/runtime#135534). Drop once the runner ships .NET 10.
    openssl-3-5,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    config = { glob = "usr/bin/actions-runner-config" } | OutputBin,
    run = { glob = "usr/bin/actions-runner" } | OutputBin,
    runner = { glob = "usr/lib/actions-runner/**", allow_executable = true } | OutputData,
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -x /usr/bin/actions-runner"],
          ["/bin/bash", "-c", "RUNNER_HOME=/tmp/runner /usr/bin/actions-runner --help || true"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      env_state_wiring = {
        env_var = "RUNNER_HOME",
        prefix = "actions-runner",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "actions",
        repo = "runner",
      },
    } | Attrs,
} | BuildSpec
