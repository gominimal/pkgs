let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.9.2" in
{
  name = "ldns",
  # NLnet Labs' DNS library (libldns), library only: no drill, no examples, no Python or
  # Perl bindings. DNSSEC crypto comes from openssl (4.x).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # The sha256 is the one NLnet Labs publishes beside the tarball
      # (ldns-%{version}.tar.gz.sha256), checked against the downloaded file.
      url = "https://nlnetlabs.nl/downloads/ldns/ldns-%{version}.tar.gz",
      sha256 = "b524fa21994b6e834200ceb8c27f1b84bda5982fe35706f058196c079db94d5d",
      extract = true,
      strip_prefix = "ldns-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [glibc, openssl],
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    libs = { glob = "usr/lib/libldns.so*" } | OutputLib,
    includes = { glob = "usr/include/ldns/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/ldns.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "NLnetLabs",
        repo = "ldns",
      },
    } | Attrs,

  tests = {
    # Build against the library through pkg-config and use it: parse an A record from
    # text, build a query packet for it, and round-trip the packet through wire format.
    link =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, pkgconf, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -euo pipefail
              [ "$(pkg-config --modversion ldns)" = '%%{version}' ]
              cat > t.c <<'EOF'
              #include <ldns/ldns.h>
              #include <stdio.h>
              #include <string.h>
              int main(void) {
                if (strcmp(ldns_version(), "%%{version}") != 0) { fprintf(stderr, "%s\n", ldns_version()); return 1; }
                ldns_rr *rr = NULL;
                if (ldns_rr_new_frm_str(&rr, "example.test. 300 IN A 192.0.2.7", 0, NULL, NULL) != LDNS_STATUS_OK) return 1;
                if (ldns_rr_get_type(rr) != LDNS_RR_TYPE_A) return 1;
                ldns_pkt *q = NULL;
                if (ldns_pkt_query_new_frm_str(&q, "example.test.", LDNS_RR_TYPE_A, LDNS_RR_CLASS_IN, LDNS_RD) != LDNS_STATUS_OK) return 1;
                uint8_t *wire = NULL; size_t len = 0;
                if (ldns_pkt2wire(&wire, q, &len) != LDNS_STATUS_OK || len < 12) return 1;
                ldns_pkt *back = NULL;
                if (ldns_wire2pkt(&back, wire, len) != LDNS_STATUS_OK) return 1;
                ldns_rr *qrr = ldns_rr_list_rr(ldns_pkt_question(back), 0);
                char *owner = ldns_rdf2str(ldns_rr_owner(qrr));
                if (strcmp(owner, "example.test.") != 0) { fprintf(stderr, "%s\n", owner); return 1; }
                return 0;
              }
              EOF
              gcc $(pkg-config --cflags ldns) t.c -o t $(pkg-config --libs ldns)
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
