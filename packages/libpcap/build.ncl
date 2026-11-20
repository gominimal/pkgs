let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in

let base = import "../base/build.ncl" in
let bison = import "../bison/build.ncl" in
let flex = import "../flex/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.11.0" in
{
  name = "libpcap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Mirror of https://www.tcpdump.org/release/libpcap-%{version}.tar.xz. Its detached
      # signature (libpcap-%{version}.tar.xz.sig) verifies against The Tcpdump Group's
      # package signing key, 1F166A5742ABB9E0249A8D30E089DEF1D9C15D0D
      # (https://www.tcpdump.org/release/signing-key-RSA-E089DEF1D9C15D0D.asc).
      url = "gs://minimal-staging-archives/libpcap-%{version}.tar.xz",
      sha256 = "9237f5bae9dcf3a91823d9963ec43b7c0e2e3374ef2ad57d92c8cd39530f4723",
      extract = true,
      strip_prefix = "libpcap-%{version}",
    } | Source,
    base,
    # The filter grammar (grammar.y.in, scanner.l) is generated at build time.
    bison,
    flex,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    libs = { glob = "usr/lib/libpcap.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/libpcap.pc" } | OutputData,
    # A /bin/sh script; it reports the flags to build against libpcap.
    pcap-config = { glob = "usr/bin/pcap-config", allow_missing_interpreter = true } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "the-tcpdump-group",
        repo = "libpcap",
      },
    } | Attrs,

  tests = {
    # Link against the library through pkg-config and pcap-config, then use it: open an
    # empty savefile written with pcap_dump_open and compile + run a BPF filter.
    link =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, pkgconf, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -euo pipefail
              pcap-config --version | grep -qx '%%{version}'
              [ "$(pkg-config --modversion libpcap)" = '%%{version}' ]
              cat > t.c <<'EOF'
              #include <pcap/pcap.h>
              #include <stdio.h>
              #include <string.h>
              int main(void) {
                const char *v = pcap_lib_version();
                if (strstr(v, "libpcap version %%{version}") != v) { fprintf(stderr, "%s\n", v); return 1; }
                pcap_t *dead = pcap_open_dead(DLT_EN10MB, 65535);
                struct bpf_program prog;
                if (pcap_compile(dead, &prog, "tcp port 80 and not host 10.0.0.1", 1, PCAP_NETMASK_UNKNOWN) != 0) {
                  fprintf(stderr, "compile: %s\n", pcap_geterr(dead)); return 1;
                }
                if (prog.bf_len == 0) return 1;
                pcap_dumper_t *d = pcap_dump_open(dead, "empty.pcap");
                if (!d) return 1;
                pcap_dump_close(d);
                char err[PCAP_ERRBUF_SIZE];
                pcap_t *r = pcap_open_offline("empty.pcap", err);
                if (!r) { fprintf(stderr, "open: %s\n", err); return 1; }
                if (pcap_datalink(r) != DLT_EN10MB || pcap_snapshot(r) != 65535) return 1;
                pcap_freecode(&prog); pcap_close(r); pcap_close(dead);
                return 0;
              }
              EOF
              gcc $(pkg-config --cflags libpcap) t.c -o t $(pkg-config --libs libpcap)
              ./t
              gcc $(pcap-config --cflags) t.c -o t2 $(pcap-config --libs)
              ./t2
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
