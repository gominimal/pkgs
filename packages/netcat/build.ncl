let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libbsd = import "../libbsd/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.239" in
let debian_revision = "1" in
{
  name = "netcat",
  build_deps = [
    { file = "build.sh" } | Local,
    # OpenBSD's nc, as packaged by Debian. The orig tarball is the OpenBSD source and does
    # not build on Linux; Debian's patch series (build.sh) ports it to libbsd and drops TLS.
    # There is no -e/-c and no TLS in this build.
    #
    # Both sha256s are the ones in Debian's PGP-signed .dsc and can be re-verified against it:
    #   https://deb.debian.org/debian/pool/main/n/netcat-openbsd/netcat-openbsd_1.239-1.dsc
    #
    # This pin goes stale silently. Version checks follow the upstream version, not the Debian
    # revision, so a new patch series is never reported. When touching this package, compare
    # against Debian's current one:
    #   curl -s https://deb.debian.org/debian/pool/main/n/netcat-openbsd/ | grep debian.tar
    {
      url = "https://deb.debian.org/debian/pool/main/n/netcat-openbsd/netcat-openbsd_%{version}.orig.tar.gz",
      sha256 = "8a2e52ea411f68c89952c944c32e4e5efbe901a566fb5fc6bbe92844a49b2a8e",
      extract = true,
      strip_prefix = "netcat-openbsd-%{version}",
    } | Source,
    {
      url = "https://deb.debian.org/debian/pool/main/n/netcat-openbsd/netcat-openbsd_%{version}-%{debian_revision}.debian.tar.xz",
      sha256 = "c0cd4380d674ef7e4dc96c2b970735b09a5e02741f50be96e6f5a2efc42e3119",
      extract = true,
    } | Source,
    base,
    make,
    patch,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    libbsd,
  ],
  cmd = "./build.sh",
  build_args = { include version, include debian_revision },
  outputs = {
    nc = { glob = "usr/bin/nc" } | OutputBin,
    netcat = { glob = "usr/bin/netcat" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "netcat-openbsd",
      license_spdx = "BSD-2-Clause AND BSD-3-Clause",
    } | Attrs,
  tests = {
    smoketest = standaloneTest "/usr/bin/nc -h",

    loopback =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          # A listener receives what a client sends it over loopback.
          [
            "/bin/bash",
            "-c",
            m%"
              set -e
              /usr/bin/nc -l 127.0.0.1 39817 > nc.out &
              srv=$!
              sleep 1
              printf ping | /usr/bin/nc -N 127.0.0.1 39817
              wait $srv
              test "$(cat nc.out)" = ping
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
