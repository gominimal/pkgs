let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let python = import "../python/build.ncl" in

let base = import "../base/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gnutls = import "../gnutls/build.ncl" in
let ldns = import "../ldns/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let nghttp2 = import "../nghttp2/build.ncl" in

# A Python DNS responder for the tests: answers every A query on 127.0.0.1:53530 (UDP and
# TCP, length-prefixed, several queries per connection) with 192.0.2.1, and counts the
# queries it answered into served.<proto>. No DNS server is packaged in pkgs yet.
let responder = m%"
  cat > responder.py <<'PYEOF'
  import socket, socketserver, struct, sys, threading
  counts = {"udp": 0, "tcp": 0}
  lock = threading.Lock()
  def answer(q):
      i = 12
      while q[i]:
          i += q[i] + 1
      question = q[12:i + 5]
      hdr = q[:2] + struct.pack(">HHHHH", 0x8180, 1, 1, 0, 0)
      rr = struct.pack(">HHHIH", 0xC00C, 1, 1, 300, 4) + socket.inet_aton("192.0.2.1")
      return hdr + question + rr
  def bump(proto):
      with lock:
          counts[proto] += 1
          open("served." + proto, "w").write(str(counts[proto]))
  class U(socketserver.BaseRequestHandler):
      def handle(self):
          data, sock = self.request
          sock.sendto(answer(data), self.client_address)
          bump("udp")
  class T(socketserver.StreamRequestHandler):
      def handle(self):
          while True:
              n = self.rfile.read(2)
              if len(n) < 2:
                  return
              q = self.rfile.read(struct.unpack(">H", n)[0])
              a = answer(q)
              self.wfile.write(struct.pack(">H", len(a)) + a)
              bump("tcp")
  class TS(socketserver.ThreadingMixIn, socketserver.TCPServer):
      allow_reuse_address = True
      daemon_threads = True
  u = socketserver.UDPServer(("127.0.0.1", 53530), U)
  t = TS(("127.0.0.1", 53530), T)
  threading.Thread(target=t.serve_forever, daemon=True).start()
  open("ready", "w").close()
  u.serve_forever()
  PYEOF
  python3 responder.py &
  srv=$!
  trap 'kill $srv 2>/dev/null || true' EXIT
  for _ in $(seq 100); do [ -e ready ] && break; sleep 0.1; done
  [ -e ready ]
  for i in $(seq 40); do echo "host$i.example.test A"; done > names.txt
"%
in

# Load the responder with every name in names.txt once (-n 1) at 100 QPS over the given
# protocol, from 2 senders of 10 queries each, then require that every query was answered:
# flame's own totals (sent, received, NOERROR, no timeouts) and the responder's count for
# that protocol must all be 40, and flame must have opened TCP connections exactly when
# the protocol is tcp. (With `-q 1`, TCP runs here took about a second per batch and hit
# the -l limit before the list was done, hence 10 queries per batch.)
let flame_run = fun proto =>
  m%"
    %{responder}
    flame -P %{proto} -p 53530 -f names.txt -n 1 -Q 100 -c 2 -q 10 -l 30 -v 0 -o metrics.json 127.0.0.1 > flame.out
    cat flame.out
    tail -n 1 metrics.json > last.json
    python3 - %{proto} <<'PYEOF'
    import json, sys
    proto = sys.argv[1]
    m = json.load(open("last.json"))
    served = int(open("served." + proto).read())
    print("flame:", {k: m.get(k) for k in ("total_s_count", "total_r_count", "total_timeouts", "total_net_errors", "total_tcp_connections", "total_responses")}, "served:", served)
    ok = (m["total_s_count"] == 40 and m["total_r_count"] == 40 and m["total_timeouts"] == 0
          and m["total_responses"] == {"NOERROR": 40} and served == 40
          and (m["total_tcp_connections"] > 0) == (proto == "tcp"))
    sys.exit(0 if ok else 1)
    PYEOF
  "%
in

let version = "0.12.0" in
let httplib_version = "0.67.0" in
{
  name = "flamethrower",
  # DNS load generator from DNS-OARC (`flame`): queries from a name list (-f) or a
  # generator, at a fixed or stepped rate (-Q, --qps-flow), over UDP, TCP, DoT and DoH,
  # with JSON metrics (-o). Upstream's README and Dockerfile build it with meson.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/DNS-OARC/flamethrower/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "3f7d792b4464ddc55ab7c3acfe250bc56751923790301798c3b3ce9516dd342d",
      extract = true,
      strip_prefix = "flamethrower-%{version}",
    } | Source,
    {
      # cpp-httplib, header-only. flamethrower 0.12.0 vendors 0.28.0 (3rd/cpp-httplib), which
      # predates 17 published advisories fixed in later releases (GHSA-wpc6-j37r-jcx7 CRLF injection,
      # GHSA-h6wq-j5mv-f3q8 negative chunk-size DoS, GHSA-jv63-rm9j-6jwc request smuggling,
      # ...). flame uses it only for the opt-in `--http-srv PORT` metrics endpoint (a
      # localhost httplib::Server), but that is still an HTTP parser on a socket, so
      # build.sh swaps in this release's httplib.h. Drop when upstream's vendored copy
      # (3rd/update_cpp-httplib.sh) is at least this version.
      url = "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v%{httplib_version}.tar.gz",
      sha256 = "be711ddaf7a3655d8f23aa5655709250b24d247aedd4b2629989d18b6164e5be",
      extract = false,
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  # gnutls for DoT/DoH, nghttp2 for DoH (upstream's default `doh` option is on).
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    gnutls,
    ldns,
    libuv,
    nghttp2,
  ],
  cmd = "./build.sh",
  build_args = { include version, include httplib_version },
  outputs = {
    flame = { glob = "usr/bin/flame" } | OutputBin,
    mans = { glob = "usr/share/man/man1/flame.1" } | OutputData,
    # The binary compiles in five bundled libraries (3rd/); their notices travel with it.
    licenses = { glob = "usr/share/licenses/flamethrower/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # flamethrower is Apache-2.0. It compiles in, from 3rd/: uvw, nlohmann/json and
      # urlparse (MIT), docopt.cpp (MIT OR BSL-1.0) and cpp-base64 (Zlib), plus
      # cpp-httplib (MIT, the newer release above). Each LICENSE was read in the tarballs;
      # all ship under usr/share/licenses/flamethrower.
      license_spdx = "Apache-2.0 AND MIT AND (MIT OR BSL-1.0) AND Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "DNS-OARC",
        repo = "flamethrower",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [["/bin/bash", "-c", "flame --version | grep -qx 'Flamethrower %{version}'"]],
      } | Test,
    help = standaloneTest "flame --help",
    udp_load =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, python],
        cmds = [["/bin/bash", "-c", "set -euo pipefail\n" ++ flame_run "udp"]],
      } | Test,
    # No test for `--http-srv` (the metrics endpoint served by the swapped-in cpp-httplib):
    # flame listens on the name "localhost", and the standalone-test sandbox has no
    # /etc/hosts, so flame aborts with "unable to listen" there. It was checked by hand in a
    # min session instead (GET /api/v1/metrics returned flame's JSON).
    tcp_load =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, python],
        cmds = [["/bin/bash", "-c", "set -euo pipefail\n" ++ flame_run "tcp"]],
      } | Test,
  },
} | BuildSpec
