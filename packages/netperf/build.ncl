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
#
# The test sandbox's only interface is lo, and netperf resolves the -H host with
# getaddrinfo(AI_ADDRCONFIG) (src/netlib.c resolve_host, src/nettest_bsd.c
# complete_addrinfo). glibc ignores loopback addresses for AI_ADDRCONFIG, so with no
# other interface even the literal 127.0.0.1 fails ("getaddrinfo returned -2 Name or
# service not known") and no test can run. On any host with a configured address (a
# lab VM) this does not happen. So the tests build a small preload that clears
# AI_ADDRCONFIG and run the real netperf and netserver with it preloaded; nothing else about
# them changes, and it is not part of the package.
let start-netserver = m%"
  gcc -shared -fPIC -o noaddrconfig.so -x c - <<'EOF'
  #define _GNU_SOURCE
  #include <dlfcn.h>
  #include <netdb.h>
  int getaddrinfo(const char *node, const char *service, const struct addrinfo *hints,
                  struct addrinfo **res) {
    static int (*real)(const char *, const char *, const struct addrinfo *,
                       struct addrinfo **);
    struct addrinfo copy;
    if (!real) real = dlsym(RTLD_NEXT, "getaddrinfo");
    if (hints) { copy = *hints; copy.ai_flags &= ~AI_ADDRCONFIG; hints = &copy; }
    return real(node, service, hints, res);
  }
  EOF
  noaddrconfig="$PWD/noaddrconfig.so"
  port=12866
  LD_PRELOAD="$noaddrconfig" netserver -D -4 -L 127.0.0.1 -p "$port" > netserver.log 2>&1 &
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
      # MIT (COPYING, and the header of every netperf source file). src/dscp.c, which
      # is compiled into both programs, is BSD-2-Clause (lifted from OpenSSH). The
      # BSD-4-Clause src/missing/inet_ntop.c is only built where libc lacks inet_ntop,
      # so not here.
      license_spdx = "MIT AND BSD-2-Clause",
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
        test_deps = [bash-bootstrap, coreutils, gawk, grep, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-netserver}
              rc=0
              out="$(LD_PRELOAD="$noaddrconfig" netperf -H 127.0.0.1 -p "$port" -t TCP_RR -l 1 2>&1)" || rc=$?
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
        test_deps = [bash-bootstrap, coreutils, gawk, grep, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{start-netserver}
              rc=0
              out="$(LD_PRELOAD="$noaddrconfig" netperf -H 127.0.0.1 -p "$port" -t UDP_RR -l 1 -P 0 -- -o THROUGHPUT,THROUGHPUT_UNITS,PROTOCOL 2>&1)" || rc=$?
              printf '%s\n' "$out"
              [ "$rc" = 0 ]
              awk -F, '$2 == "Trans/s" && $3 == "UDP" && $1 + 0 > 0 { ok = 1 } END { exit !ok }' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
