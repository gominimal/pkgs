let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in

let base = import "../base/build.ncl" in
let c-ares = import "../c-ares/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let libev = import "../libev/build.ncl" in
let nghttp3 = import "../nghttp3/build.ncl" in
let ngtcp2 = import "../ngtcp2/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

# The nghttp2 programs: h2load (HTTP/1.1, HTTP/2 and HTTP/3 load tester), nghttp (client),
# nghttpd (HTTP/2 server) and nghttpx (proxy). A package of its own rather than an output
# of `nghttp2`: runtime_deps belong to a whole package, so an apps output there would hand
# libev, c-ares, ngtcp2 and nghttp3 to every consumer of libnghttp2 (node, node-lts,
# node-24, zellij, microvm-rootfs) and rehash all of them. Built from the same release
# tarball as `nghttp2`, with libnghttp2 linked statically (see build.sh).
let version = "1.71.0" in

# Shared test setup: a self-signed P-256 certificate for 127.0.0.1 and a 4 KiB file to
# serve. `wait_ok <h2load args>` retries a one-request h2load run until it succeeds, so a
# test starts only once its server accepts. `load <args>` runs 200 requests over 4
# clients and requires every one to succeed with the protocol named first.
let prelude = m%"
  set -euo pipefail
  mkdir www && head -c 4096 /dev/zero > www/blob
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 1 \
    -subj /CN=localhost -addext subjectAltName=DNS:localhost,IP:127.0.0.1 \
    -keyout key.pem -out cert.pem 2>/dev/null
  pids=()
  trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT
  wait_ok() {
    for _ in $(seq 100); do
      probe="$(h2load -n 1 "$@" 2>&1 || true)"
      if grep -q ' 1 succeeded,' <<<"$probe"; then return 0; fi
      sleep 0.1
    done
    echo "server never answered: $*" >&2; cat ./*.log >&2; return 1
  }
  load() {
    proto=$1; shift
    out="$(h2load -n 200 -c 4 "$@")"
    printf '%s\n' "$out"
    grep -qx "Application protocol: $proto" <<<"$out"
    grep -q '^requests: 200 total, 200 started, 200 done, 200 succeeded, 0 failed, 0 errored, 0 timeout$' <<<"$out"
  }
"%
in
{
  name = "nghttp2-apps",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nghttp2/nghttp2/releases/download/v%{version}/nghttp2-%{version}.tar.gz",
      sha256 = "0cdd35ecec77919b4b7b245f87fe8d2216e3d62da854eb0838c594ff058042fc",
      extract = true,
      strip_prefix = "nghttp2-%{version}",
    } | Source,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    c-ares,
    # nghttpx verifies a TLS backend against the system trust store unless given
    # --cacert or -k; declare the store it reads.
    ca-certificates,
    libev,
    nghttp3,
    ngtcp2,
    openssl,
    zlib,
  ],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    h2load = { glob = "usr/bin/h2load" } | OutputBin,
    nghttp = { glob = "usr/bin/nghttp" } | OutputBin,
    nghttpd = { glob = "usr/bin/nghttpd" } | OutputBin,
    nghttpx = { glob = "usr/bin/nghttpx" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "nghttp2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nghttp2",
        repo = "nghttp2",
      },
    } | Attrs,
  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              h2load --version | grep -qx 'h2load nghttp2/%{version}'
              nghttp --version | grep -q '^nghttp nghttp2/%{version}'
              nghttpd --version | grep -q '^nghttpd nghttp2/%{version}'
              # nghttpx names the QUIC libraries only when built with HTTP/3.
              nghttpx --version | grep -Eqx 'nghttpx nghttp2/%{version} ngtcp2/[0-9.]+ nghttp3/[0-9.]+'
              # Capture before grep -q: grep exits on the first match, the writer then
              # gets SIGPIPE, and pipefail fails the test with 141 (ghz, pkgs#1645).
              h=$(h2load --help)
              grep -q -- '--h3' <<<"$h"
            "%
          ],
        ],
      } | Test,
    # h2load and nghttp against nghttpd: HTTP/2 cleartext (prior knowledge) and HTTP/2
    # over TLS.
    h2_against_nghttpd =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              %{prelude}
              nghttpd --no-tls -d www 18080 > h2c.log 2>&1 & pids+=($!)
              nghttpd -d www 18443 key.pem cert.pem > h2.log 2>&1 & pids+=($!)
              wait_ok http://127.0.0.1:18080/blob
              wait_ok https://127.0.0.1:18443/blob
              load h2c http://127.0.0.1:18080/blob
              load h2 https://127.0.0.1:18443/blob
              v=$(nghttp -v -n http://127.0.0.1:18080/blob)
              grep -q ':status: 200' <<<"$v"
            "%
          ],
        ],
      } | Test,
    # HTTP/3 and HTTP/1.1: nghttpx listens for QUIC and TLS on one port and proxies to an
    # h2c nghttpd backend; h2load drives it with --h3 and --h1.
    h3_and_h1_through_nghttpx =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              %{prelude}
              nghttpd --no-tls -d www 18080 > backend.log 2>&1 & pids+=($!)
              nghttpx --conf=/dev/null -f'127.0.0.1,19443;quic' -f'127.0.0.1,19443' \
                -b'127.0.0.1,18080;;proto=h2' key.pem cert.pem > proxy.log 2>&1 & pids+=($!)
              wait_ok --h1 https://127.0.0.1:19443/blob
              wait_ok --h3 https://127.0.0.1:19443/blob
              load h3 --h3 https://127.0.0.1:19443/blob
              load http/1.1 --h1 https://127.0.0.1:19443/blob
            "%
          ],
        ],
      } | Test,
    # Against a closed port h2load reports the failure and makes no progress (it exits 0
    # either way, so the summary line is what is checked).
    closed_port =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              out="$(h2load -n 1 http://127.0.0.1:1/ 2>&1)"
              printf '%s\n' "$out"
              grep -q '^requests: 1 total, 0 started, 0 done, 0 succeeded, 1 failed, 1 errored' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
