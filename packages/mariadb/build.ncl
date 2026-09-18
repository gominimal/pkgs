let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

# MariaDB CLIENT only — the `mariadb` / `mysql` CLI and the client libraries.
#
# This is what Fedora's `dnf install mariadb` actually gives you: the client
# package, not mariadb-server. The agentbox image wants a CLI to talk to a
# database somewhere else, so building and shipping a server would be several
# hundred MB of storage engines nothing in the image runs.
#
# Built from the SERVER source tarball because that is where the client lives —
# mariadb-connector-c provides libmariadb but no CLI. `-DWITHOUT_SERVER=ON` is
# upstream's own switch for this, and it is what makes the build tractable.
#
# Source is MariaDB's official release tarball from archive.mariadb.org,
# mirrored to gs:// like every other non-github source here. 12.3 is the
# current Stable LTS series.
let version = "12.3.3" in

{
  name = "mariadb",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mariadb-%{version}.tar.gz",
      sha256 = "c50530dac99930932a7e5375719a5adb41a9f538c13ab751d84b9dcbcd47181a",
      extract = true,
      strip_prefix = "mariadb-%{version}",
    } | Source,
    base,
    cmake,
    make,
    pkgconf,
    toolchain,
    ncurses,
    openssl,
    zlib,
  ],

  runtime_deps = [
    glibc,
    ncurses,
    openssl,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**/*.so*" } | OutputLib,
    data = { glob = "usr/share/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      repology_project = "mariadb",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/mariadb --version | grep -qi mariadb"],
          # The client must parse options and exit cleanly without a server;
          # --help exercises far more of it than --version does.
          ["/bin/bash", "-c", "/bin/mariadb --help >/dev/null"],
        ],
      } | Test,
  },
} | BuildSpec
