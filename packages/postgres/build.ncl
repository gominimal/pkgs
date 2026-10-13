let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in # `locale`, for the initdb test fallback
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let icu = import "../icu/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# Minimal sessions set LANG=C.UTF-8, which the glibc locale-archive lacks;
# without it `initdb` aborts with "invalid locale settings".
let glibc-locale-c-utf8 = import "../glibc-locale-c-utf8/build.ncl" in

let version = "18.6" in
{
  name = "postgres",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/postgresql-%{version}.tar.gz",
      sha256 = "983ee554ec53dbeb9b70797bef9fcf4e67e117e7e48ca1463cc80b3ff8e8ff3f",
    } | Source,
    base,
    make,
    perl,
    toolchain,
    flex,
    bison,
    m4,
    pkgconf,
  ],
  runtime_deps = [
    openssl,
    readline,
    icu,
    zstd,
    zlib,
    glibc-locale-c-utf8,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**", allow_data = true } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    share = { glob = "usr/share/postgresql/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "PostgreSQL",
      source_provenance = {
        category = 'GithubRepo,
        owner = "postgres",
        repo = "postgres",
      },
    } | Attrs,
  tests = {
    # A default `initdb` under the session locale must succeed and pick UTF8.
    # initdb always looks up the running user, and CI runs tests as a bare uid
    # with no passwd entry: add one where /etc/passwd is writable. Where it is
    # read-only (build-bot), initdb cannot run at all, so check the property
    # it depends on instead: the C.UTF-8 locale loads (a missing locale makes
    # `locale charmap` print ANSI_X3.4-1968).
    initdb_c_utf8 =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "if ! id -un >/dev/null 2>&1 && ! { echo \"pgtest:x:$(id -u):$(id -g)::/tmp:/bin/sh\" >> /etc/passwd; } 2>/dev/null; then echo \"uid $(id -u) has no passwd entry and /etc/passwd is read-only; checking the C.UTF-8 locale directly\" >&2; c=$(LC_ALL=C.UTF-8 locale charmap 2>&1); [ \"$c\" = UTF-8 ] || { echo \"C.UTF-8 did not load: $c\" >&2; exit 1; }; exit 0; fi; d=$(mktemp -d) && LANG=C.UTF-8 LC_ALL= /bin/initdb -D \"$d/data\" >\"$d/log\" 2>&1 || { cat \"$d/log\" >&2; exit 1; }; grep -q 'encoding has accordingly been set to \"UTF8\"' \"$d/log\""],
        ],
      } | Test,
  },
} | BuildSpec
