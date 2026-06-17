let { Attrs, BuildSpec, Local, OutputBin, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libarchive = import "../libarchive/build.ncl" in

# `unzip` is now a thin compatibility shim: it installs a `/usr/bin/unzip`
# wrapper script that execs libarchive's `bsdunzip`, the maintained successor to
# the EOL Info-ZIP unzip (frozen since 2009, carrying unfixed
# CVE-2014-8139/8140/8141 + CVE-2018-1000035). A wrapper, not a symlink — the
# sandbox rejects symlinks pointing outside a package's own output, and bsdunzip
# lives in libarchive's output. bsdunzip is a drop-in for the flags our
# consumers use (`-o`/`-q`/`-d`/`-p`); existing callers (bun, chromium-bin,
# chromium-headless-shell-bin) keep invoking `unzip` unchanged. Version-tracking
# follows libarchive (this also un-darkens it for `pkgmgr check`).
{
  name = "unzip",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
  ],
  runtime_deps = [
    glibc,
    libarchive,
  ],

  cmd = "./build.sh",

  outputs = {
    # A /bin/sh wrapper that execs bsdunzip (provided by the libarchive runtime
    # dep). allow_missing_interpreter: the /bin/sh shebang is satisfied by the
    # base system at runtime, same as xz's script bins.
    unzip = { glob = "usr/bin/unzip", allow_missing_interpreter = true } | OutputBin,
  },

  attrs =
    {
      upstream_version = "3.8.7",
      license_spdx = "BSD-2-Clause",
      repology_project = "libarchive",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libarchive",
        repo = "libarchive",
      },
    } | Attrs,

  tests = {
    roundtrip =
      {
        class = 'Standalone,
        test_deps = [base, libarchive],
        cmds = [
          # Extract a tiny zip built inline (one file "hello" containing
          # "hello\n") through the unzip->bsdunzip symlink.
          [
            "/bin/bash",
            "-c",
            m%"
              printf 'PK\x03\x04\x14\x00\x00\x00\x00\x00\x00\x00!\x00\xb1y\xa7"\x06\x00\x00\x00\x06\x00\x00\x00\x05\x00\x00\x00hellohello\nPK\x01\x02\x14\x00\x14\x00\x00\x00\x00\x00\x00\x00!\x00\xb1y\xa7"\x06\x00\x00\x00\x06\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00helloPK\x05\x06\x00\x00\x00\x00\x01\x00\x01\x003\x00\x00\x00)\x00\x00\x00\x00\x00' > t.zip
              /bin/unzip -p t.zip hello | /bin/grep -q '^hello$'
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
