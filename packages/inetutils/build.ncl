let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.8" in
{
  name = "inetutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/inetutils-%{version}.tar.gz",
      sha256 = "57b3cf4f77555992881e5ba2a09a63b05aa2c56342a60ed4305b5f45938390b5"
    } | Source,
    base,
    make,
    sed,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
  },
  tests = {
    # pkgs#849: upstream's setuid install hook left these 0600 (shipped 0644)
    # when the build ran unprivileged. They must be executable, and not setuid.
    # Only --version is run: in a sandbox ping and traceroute cannot open the
    # ICMP sockets they need, and argp handles --version before that.
    exec_bits =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "for b in ping ping6 traceroute; do test -x /usr/bin/$b && ! test -u /usr/bin/$b || { ls -l /usr/bin/$b; exit 1; }; done"],
          ["/usr/bin/ping", "--version"],
          ["/usr/bin/ping6", "--version"],
          ["/usr/bin/traceroute", "--version"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "inetutils",
      },
    } | Attrs,
} | BuildSpec
