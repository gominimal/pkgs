let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let icu = import "../icu/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let openssl = import "../openssl/build.ncl" in
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
  # CVE-2026-111943: the wrappers export NODE_OPTIONS=--use-openssl-ca, so the
  # bundled externals/node{20,24} trust ca-certificates (OpenSSL's default
  # store, OPENSSLDIR=/etc/ssl) instead of their compiled-in roots, which still
  # hold emSign ECC Root CA - G3. The .NET listener already used OpenSSL's store.
  #
  # Not done by swapping externals/node* for our node-lts: the runner mounts
  # externals/ into job containers at /__e and runs actions with
  # /__e/node24/bin/node there, so a symlink would dangle inside the container
  # and our node (linked against our glibc) would not run in it anyway.
  # Container jobs keep the bundled node and the container image's store,
  # unchanged. node20 is kept for the same reason: the runner still selects it
  # for an action declaring `using: node20` when the job opts out of the
  # node24 default (ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION); the flag covers
  # it too.
  runtime_deps = [
    bash,
    ca-certificates,
    glibc,
    icu,
    openssl,
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
    # CVE-2026-111943: under the wrapper, the bundled node trusts the system
    # store, not its compiled-in roots. A throwaway CA is added to a copy of
    # ca-certificates and handed over with SSL_CERT_FILE (OpenSSL's override);
    # only a node reading OpenSSL's store can then verify a local server whose
    # leaf that CA signed. Control: the same node outside the wrapper refuses it.
    bundled_node_uses_system_store =
      {
        class = 'Standalone,
        test_deps = [base, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              d=$(mktemp -d); cd "$d"
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout ca.key -out ca.pem -days 2 -subj /CN=throwaway-test-ca 2>/dev/null
              openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout leaf.key -out leaf.csr -subj /CN=localhost 2>/dev/null
              printf 'subjectAltName=DNS:localhost
basicConstraints=CA:FALSE
extendedKeyUsage=serverAuth
' > leaf.ext
              openssl x509 -req -in leaf.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 1 -extfile leaf.ext -out leaf.pem 2>/dev/null
              cat /etc/ssl/cert.pem ca.pem > bundle.pem
              openssl s_server -accept 127.0.0.1:18443 -cert leaf.pem -key leaf.key -www -quiet & srv=$!
              trap 'kill $srv 2>/dev/null || true' EXIT
              sleep 1
              # A RUNNER_HOME whose run.sh just runs its arguments, so the
              # wrapper's environment reaches the bundled node as it would.
              mkdir -p rh/bin; ln -s /usr/lib/actions-runner/externals rh/externals
              printf '#!/bin/bash
exec "$@"
' > rh/run.sh; chmod +x rh/run.sh
              js="require('https').get('https://localhost:18443/', (r) => { console.log('ok', r.statusCode); process.exit(0) }).on('error', (e) => { console.log('refused', e.code); process.exit(1) })"
              for n in node20 node24; do
                echo "$n via wrapper:"
                RUNNER_HOME=$d/rh SSL_CERT_FILE=$d/bundle.pem /usr/bin/actions-runner "externals/$n/bin/node" -e "$js"
                echo "$n without wrapper (must refuse):"
                if SSL_CERT_FILE=$d/bundle.pem "/usr/lib/actions-runner/externals/$n/bin/node" -e "$js"; then
                  echo "control failed: bundled $n trusted the system store without the wrapper" >&2; exit 1
                fi
              done
            "%
          ],
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
