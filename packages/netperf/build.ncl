let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in

let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# netperf's last release, netperf-2.7.0 (2015), is under HP's 1993 licence, which
# allows distribution "for non-commercial purposes only". The MIT licence (COPYING)
# arrived on master in 2021 (HewlettPackard/netperf#54) and no release has been tagged
# since, so this pins master: afc51ff (2025-07-28) is its head, and its configure.ac
# calls it 2.7.1 (AC_INIT), which `netperf -V` reports. That commit is also upstream's
# fix for building with GCC 10+ (-fno-common: nettest_omni.c's `extern int loc_nodelay`),
# so no patch is carried.
let commit = "afc51ff9764741da4ed6702651fba9d9c23f8557" in
let version = "2.7.1" in

# Start netserver on loopback in the foreground (-D) and wait until it accepts the
# control connection. 127.0.0.1, not localhost: the test sandbox has no /etc/hosts.
# The sandbox's only interface is lo, which is why build.sh drops AI_ADDRCONFIG: these
# tests run the shipped binaries unmodified.
let start-netserver = m%"
  port=12866
  netserver -D -4 -L 127.0.0.1 -p "$port" > netserver.log 2>&1 &
  srv=$!
  trap 'kill "$srv" 2>/dev/null || true; cat netserver.log' EXIT
  for _ in $(seq 1 50); do
    (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
    sleep 0.1
  done
"%
in
{
  name = "netperf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/HewlettPackard/netperf/archive/%{commit}.tar.gz",
      sha256 = "f7bca9d7faabd2bb27009013fa7df605f38a4e6a513697bad74355d2814b12cd",
      extract = true,
      strip_prefix = "netperf-%{commit}",
    } | Source,
    autoconf,
    automake,
    base,
    m4,
    make,
    perl,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    netperf = { glob = "usr/bin/netperf" } | OutputBin,
    netserver = { glob = "usr/bin/netserver" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # MIT (COPYING, and most netperf source headers). src/dscp.c, compiled into both
      # programs, is BSD-2-Clause (lifted from OpenSSH). src/net_uuid.c, also compiled
      # into both, is the RFC 4122 sample code under the OSF/HP/DEC/Microsoft notice
      # ("permission to use, copy, modify, and distribute this file for any purpose",
      # keep the notices, no use of the names in advertising); SPDX has no id for it.
      # The BSD-4-Clause src/missing/inet_ntop.c is only built where libc lacks
      # inet_ntop, so not here.
      license_spdx = "MIT AND BSD-2-Clause AND LicenseRef-RFC4122-OSF-sample",
      source_provenance = {
        category = 'GithubRepo,
        owner = "HewlettPackard",
        repo = "netperf",
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
              v="$(netperf -V)"
              printf '%s\n' "$v"
              grep -qx 'Netperf version %{version}' <<<"$v"
            "%
          ],
        ],
      } | Test,
    # netperf -t TCP_RR against a local netserver: the classic report's last data row
    # carries "Trans. Rate per sec", which must be a positive number.
    tcp_rr =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, gawk, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-netserver}
              rc=0
              out="$(netperf -H 127.0.0.1 -p "$port" -t TCP_RR -l 1 2>&1)" || rc=$?
              printf '%s\n' "$out"
              [ "$rc" = 0 ]
              grep -q 'TCP REQUEST/RESPONSE TEST' <<<"$out"
              grep -q 'Trans\.' <<<"$out"
              rate="$(awk 'NF == 6 && $6 ~ /^[0-9]+\.[0-9]+$/ { r = $6 } END { print r }' <<<"$out")"
              echo "TCP_RR transactions/s: $rate"
              awk -v r="$rate" 'BEGIN { exit !(r + 0 > 0) }'
            "%
          ],
        ],
      } | Test,
    # The same for UDP_RR, read through the omni output selectors.
    udp_rr =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, gawk, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-netserver}
              rc=0
              out="$(netperf -H 127.0.0.1 -p "$port" -t UDP_RR -l 1 -P 0 -- -o THROUGHPUT,THROUGHPUT_UNITS,PROTOCOL 2>&1)" || rc=$?
              printf '%s\n' "$out"
              [ "$rc" = 0 ]
              awk -F, '$2 == "Trans/s" && $3 == "UDP" && $1 + 0 > 0 { ok = 1 } END { exit !ok }' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
