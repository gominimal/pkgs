let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.22.1" in

# Start a server on loopback, wait until it accepts, run one client test against it and
# require a non-zero receiver bitrate. `flags` are extra client options.
let loopback = fun flags =>
  m%"
    set -euo pipefail
    iperf3 -s -B 127.0.0.1 -p 5201 > server.log 2>&1 &
    server=$!
    trap 'kill "$server" 2>/dev/null || true' EXIT
    ok=
    for _ in $(seq 100); do
      if iperf3 -c 127.0.0.1 -p 5201 -t 1 %{flags} > out 2>&1; then ok=1; break; fi
      grep -q 'Connection refused' out || break
      sleep 0.1
    done
    cat out
    [ -n "$ok" ] || { cat server.log >&2; exit 1; }
    grep -E 'receiver' out | grep -Eq '([1-9][0-9]*(\.[0-9]+)?|0\.0*[1-9][0-9]*) [KMG]?bits/sec'
  "%
in
{
  name = "iperf3",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # GitHub release asset (not the tag archive): it carries the generated configure.
      # Its sha256 matches the iperf-%{version}.tar.gz.sha256 published beside it.
      url = "https://github.com/esnet/iperf/releases/download/%{version}/iperf-%{version}.tar.gz",
      sha256 = "de018b5252e2a7068c89fac8b35a295d83334f2b7814aa9532a2a8107b04a4a9",
      extract = true,
      strip_prefix = "iperf-%{version}",
    } | Source,
    base,
    make,
    openssl,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    openssl,
  ],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    iperf3 = { glob = "usr/bin/iperf3" } | OutputBin,
    libs = { glob = "usr/lib/libiperf.so*" } | OutputLib,
    includes = { glob = "usr/include/iperf_api.h" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # LICENSE: iperf itself is the LBNL BSD variant (three clauses naming UC, LBNL and
      # DOE, plus the "Enhancements" grant), SPDX BSD-3-Clause-LBNL. The binary also
      # compiles in src/cjson.c (MIT), src/net.c (MIT, Russ Cox / MIT; plus a BSD-3-Clause
      # part by Eric Jackson), src/queue.h (BSD-3-Clause, UC) and src/units.c (the iperf2
      # NCSA licence). GitHub's licence API reports NOASSERTION for this file.
      license_spdx = "BSD-3-Clause-LBNL AND MIT AND BSD-3-Clause AND NCSA",
      source_provenance = {
        category = 'GithubRepo,
        owner = "esnet",
        repo = "iperf",
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
              v="$(iperf3 --version)"
              printf '%s\n' "$v"
              grep -q '^iperf %{version} ' <<<"$v"
              grep -q 'authentication' <<<"$v"
            "%
          ],
        ],
      } | Test,
    # A real transfer over loopback: TCP, TCP reversed (server sends), and UDP at a fixed
    # 10 Mbit/s target.
    tcp_loopback =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [["/bin/bash", "-c", loopback ""]],
      } | Test,
    tcp_reverse_loopback =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [["/bin/bash", "-c", loopback "-R"]],
      } | Test,
    udp_loopback =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [["/bin/bash", "-c", loopback "-u -b 10M"]],
      } | Test,
  },
} | BuildSpec
