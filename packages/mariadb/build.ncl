let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in
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
      sha256 = "e99d739fd4a55f9a11dea7bd2287a262673e287550af3071c8469dd2bec0c163",
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
    pcre2,
    zlib,
  ],

  runtime_deps = [
    # bash carries /bin/sh, the interpreter for the mysql_config / mariadb_config
    # scripts. Every other interpreted script the install produced is a
    # server-administration Perl tool and is removed in build.sh, so this is the
    # only interpreter the package needs.
    bash,
    glibc,
    ncurses,
    openssl,
    # mariadb-import and mariadb-test link libpcre2-posix.so.3. MariaDB bundles a
    # copy of PCRE2 but prefers a system one when it finds it, and it finds ours
    # through the toolchain, so the dep is real and was caught by the
    # missing-runtime_deps checker rather than guessed at.
    pcre2,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # The development files ship because the client helpers we keep are only
  # truthful if they do. mysql_config / mariadb_config answer --cflags with
  # -I/usr/include/mysql and --libs with -L/usr/lib -lmariadb; exporting the
  # library but not the headers it describes would make those scripts hand out
  # an include path for a directory that is not in the package (CodeRabbit on
  # #723). Shipping the .so without the headers is the incoherent half-state —
  # either both or neither, and libmariadb is worth having.
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**/*.so*" } | OutputLib,
    # usr/include/mysql/** in practice; the wider glob also catches anything
    # upstream relocates.
    includes = { glob = "usr/include/**" } | OutputData,
    # libmariadb.pc, so pkg-config can answer the same questions mysql_config
    # does. Both are installed; shipping only one would leave consumers
    # depending on which mechanism they happen to use.
    pkgconfig = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    # NOT usr/share/man: this build installs man pages to usr/man/man{1,3}, so
    # the usr/share/** glob below never claimed them and they were silently
    # dropped from the package.
    mans = { glob = "usr/man/**" } | OutputData,
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

    # Assert the client helpers do not lie.
    #
    # Keeping mysql_config is only defensible if the paths it reports are
    # actually in the package. This walks the -I flags it prints and requires
    # that one of them really contains mysql.h, which is exactly the condition
    # that was false before the `includes` output was added: the scripts
    # shipped, the header did not, and every other test still passed.
    #
    # It can disagree — drop the `includes` output and this fails.
    dev_files_are_usable =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -eu\nfound=0\nfor tok in $(/bin/mysql_config --cflags); do\n  case \"$tok\" in\n    -I*) d=${tok#-I}; [ -f \"$d/mysql.h\" ] && found=1 ;;\n  esac\ndone\nif [ \"$found\" != 1 ]; then\n  echo \"mysql_config --cflags names no directory containing mysql.h:\" >&2\n  /bin/mysql_config --cflags >&2\n  exit 1\nfi"],
          # The .so that mysql_config --libs advertises must be present too.
          ["/bin/bash", "-c", "set -eu\ntest -e /usr/lib/libmariadb.so"],
        ],
      } | Test,
  },
} | BuildSpec
