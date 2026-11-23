let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let go = import "../go/build.ncl" in
let grep = import "../grep/build.ncl" in
let socat = import "../socat/build.ncl" in

# Toxiproxy: a TCP proxy whose links can be made slow, lossy or broken on
# demand ("toxics"), for network-fault scenarios. toxiproxy-server is the
# proxy and its HTTP API (port 8474); toxiproxy-cli drives that API. Both are
# static Go binaries (CGO_ENABLED=0), as upstream releases them.
let version = "2.13.0" in
{
  name = "toxiproxy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Shopify/toxiproxy/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6fe013a718a2d3595b26cd51536dfe3f32a1e346df7a7692e85c65c2cb1b680a",
      extract = true,
    } | Source,
    base,
    go,
  ],
  runtime_deps = [],
  # Go module downloads (verified against go.sum).
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    toxiproxy-server = { glob = "usr/bin/toxiproxy-server" } | OutputBin,
    toxiproxy-cli = { glob = "usr/bin/toxiproxy-cli" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "toxiproxy",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Shopify",
        repo = "toxiproxy",
      },
    } | Attrs,

  tests = {
    # A socat backend answers "pong". toxiproxy-cli puts a proxy in front of
    # it; a latency toxic must delay the answer by at least its 1500 ms, and a
    # reset_peer toxic must drop the answer and reset the connection (the
    # backend's socat reports "Connection reset by peer"; the client sees an
    # empty, closed stream). The sandbox has no /etc/hosts, so every address
    # is 127.0.0.1, never localhost.
    latency_and_reset =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, socat],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              toxiproxy-server -version | grep -qF "version %{version}"
              toxiproxy-cli --version | grep -qF "%{version}"
              d=$(mktemp -d)
              socat TCP-LISTEN:16379,bind=127.0.0.1,reuseaddr,fork EXEC:'echo pong' 2>"$d/backend.err" &
              spid=$!
              toxiproxy-server -host 127.0.0.1 -port 8474 >"$d/server.log" 2>&1 &
              tpid=$!
              trap 'kill $spid $tpid 2>/dev/null || true; cat "$d/server.log"' EXIT
              cli() { toxiproxy-cli --host http://127.0.0.1:8474 "$@"; }
              for i in $(seq 50); do cli list >/dev/null 2>&1 && break; sleep 0.2; done
              cli create --listen 127.0.0.1:26379 --upstream 127.0.0.1:16379 echo
              # One connection through the proxy: what came back, and how long it took.
              fetch() {
                local t0 t1
                t0=$(date +%s%N)
                exec 3<>/dev/tcp/127.0.0.1/26379
                out=$(timeout 10 cat <&3 || true)
                exec 3<&-
                t1=$(date +%s%N)
                ms=$(( (t1 - t0) / 1000000 ))
              }
              fetch
              echo "no toxic: '$out' in ${ms} ms"
              [ "$out" = pong ]
              [ "$ms" -lt 1000 ]
              cli toxic add --type latency --attribute latency=1500 --toxicName lag echo
              cli inspect echo | grep -q lag
              fetch
              echo "latency toxic: '$out' in ${ms} ms"
              [ "$out" = pong ]
              [ "$ms" -ge 1500 ]
              cli toxic remove --toxicName lag echo
              cli toxic add --type reset_peer --attribute timeout=0 --toxicName rst echo
              fetch
              echo "reset_peer toxic: '$out' in ${ms} ms"
              [ -z "$out" ]
              [ "$ms" -lt 5000 ]
              # Only the reset_peer connection may have been reset.
              for i in $(seq 25); do grep -q 'reset by peer' "$d/backend.err" && break; sleep 0.2; done
              cat "$d/backend.err"
              [ "$(grep -c 'reset by peer' "$d/backend.err")" = 1 ]
              cli delete echo
              # (not `! ...`: set -e does not apply to a negated pipeline)
              if cli list | grep -q echo; then exit 1; fi
              echo PASS
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
