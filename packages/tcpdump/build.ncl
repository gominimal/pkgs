let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let libcap-ng = import "../libcap-ng/build.ncl" in
let libpcap = import "../libpcap/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.99.7" in

# One UDP datagram, 10.0.0.1:1234 -> 10.0.0.2:9999, payload "hi", in a classic
# little-endian pcap savefile with link type 101 (LINKTYPE_RAW: the packet starts at the
# IPv4 header), timestamp 1.000000. Written with printf so the tests need no fixture.
let write-pcap = m%"
  printf '\xd4\xc3\xb2\xa1\x02\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\x00\x00\x65\x00\x00\x00' > udp.pcap
  printf '\x01\x00\x00\x00\x00\x00\x00\x00\x1e\x00\x00\x00\x1e\x00\x00\x00' >> udp.pcap
  printf '\x45\x00\x00\x1e\x00\x00\x00\x00\x40\x11\x66\xcd\x0a\x00\x00\x01\x0a\x00\x00\x02' >> udp.pcap
  printf '\x04\xd2\x27\x0f\x00\x0a\x00\x00\x68\x69' >> udp.pcap
"%
in
let expected = "1.000000 IP 10.0.0.1.1234 > 10.0.0.2.9999: UDP, length 2" in
{
  name = "tcpdump",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Mirror of https://www.tcpdump.org/release/tcpdump-%{version}.tar.xz. Its detached
      # signature (tcpdump-%{version}.tar.xz.sig) verifies against The Tcpdump Group's
      # package signing key, 1F166A5742ABB9E0249A8D30E089DEF1D9C15D0D
      # (https://www.tcpdump.org/release/signing-key-RSA-E089DEF1D9C15D0D.asc).
      url = "gs://minimal-staging-archives/tcpdump-%{version}.tar.xz",
      sha256 = "39675dfa06fb0e99be8da5d4a1784acbaab58ae0870231d956ff7870cb99eec1",
      extract = true,
      strip_prefix = "tcpdump-%{version}",
    } | Source,
    base,
    libcap-ng,
    libpcap,
    make,
    openssl,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    libcap-ng,
    libpcap,
    openssl,
  ],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    tcpdump = { glob = "usr/bin/tcpdump" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "the-tcpdump-group",
        repo = "tcpdump",
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
              v="$(tcpdump --version)"
              printf '%s\n' "$v"
              grep -qx 'tcpdump version %{version}' <<<"$v"
              grep -q '^libpcap version [0-9]' <<<"$v"
              grep -q '^OpenSSL 4\.' <<<"$v"
            "%
          ],
        ],
      } | Test,
    # Read a savefile, with and without a filter (libpcap compiles and runs the BPF
    # program), and write it back out with -w and read that.
    read =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              %{write-pcap}
              out="$(tcpdump -n -tt -r udp.pcap)"
              printf '%s\n' "$out"
              [ "$out" = '%{expected}' ]
              [ "$(tcpdump -n -tt -r udp.pcap 'udp dst port 9999 and src host 10.0.0.1')" = '%{expected}' ]
              [ -z "$(tcpdump -n -tt -r udp.pcap 'tcp or udp port 53')" ]
              tcpdump -n -r udp.pcap -w copy.pcap udp
              [ "$(tcpdump -n -tt -r copy.pcap)" = '%{expected}' ]
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
