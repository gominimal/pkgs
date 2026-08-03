let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "0.9.1" in
{
  name = "rizin",
  build_deps = [
    { file = "build.sh" } | Local,
    # The official `rizin-src` tarball, NOT a GitHub tag archive: it vendors
    # the meson subprojects (capstone-next, tree-sitter, pcre2, lz4, nettle,
    # blake2/3, libmspack, softfloat, libzip...), which is what lets the build
    # run with --wrap-mode=nodownload and no network.
    {
      url = "https://github.com/rizinorg/rizin/releases/download/v%{version}/rizin-src-v%{version}.tar.xz",
      sha256 = "7ac1cd7daca7afdda742e15478b1f747fc1f813e496fee71839d1e109e543dca",
    } | Source,
    base,
    toolchain,
    gcc,
    meson,
    ninja,
    pkgconf,
    python, # meson is Python
    glibc,
    # The seven libraries we link from the SYSTEM rather than let rizin vendor,
    # so a CVE in any of them is visible to pkgscan instead of buried in a
    # static blob. See the use_sys_* rationale in build.sh.
    zlib,
    zstd,
    xz,
    lz4,
    pcre2,
    openssl,
    tree-sitter,
  ],
  runtime_deps = [
    bash,
    glibc,
    zlib,
    zstd,
    xz,
    lz4,
    pcre2,
    openssl,
    tree-sitter,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # The headless/scriptable counterpart to Ghidra: Ghidra answers "what does
    # this function do", rizin answers "run that over 400 binaries and diff the
    # results".
    rizin = { glob = "usr/bin/rizin" } | OutputBin,
    rz_bins = { glob = "usr/bin/rz-*" } | OutputBin,
    librz = { glob = "usr/lib/librz*.so*" } | OutputLib,
    rz_data = { glob = "usr/share/rizin/**" } | OutputData,
  },

  tests = {
    smoketest = standaloneTest "/bin/rizin -v",

    # Pin the two properties the use_sys_* flags exist for. Both regress
    # SILENTLY: meson probes for each system library and falls back to the
    # vendored subproject when one is not found, printing a note and carrying
    # on to a successful build. You would get a rizin that works perfectly and
    # has seven invisible bundled libraries — the exact outcome these flags
    # exist to prevent, and one nothing else here would detect.
    system_libs =
      {
        class = 'Standalone,
        # binutils for readelf. The first version of this test used readelf
        # with only `base` declared and failed with "readelf: command not
        # found" — loudly, which is the correct behaviour and how this was
        # caught, but it is a dependency and belongs here.
        test_deps = [base, binutils],
        cmds = [
          # Assert on the librz_* SHARED LIBRARIES, not on /usr/bin/rizin:
          # the rizin binary is a thin frontend and carries none of these in
          # its own DT_NEEDED — the linkage lives in the libraries. Checking
          # the wrong file would have produced a test that always failed.
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              need="libz.so libzstd liblzma liblz4 libpcre2 libcrypto libtree-sitter"
              all=$(readelf -d /usr/lib/librz*.so.* 2>/dev/null)
              for lib in $need; do
                case "$all" in
                  *"$lib"*) ;;
                  *) echo "$lib is NOT linked from the system — the use_sys_* flag" >&2
                     echo "silently fell back to rizin's vendored copy, which pkgscan" >&2
                     echo "cannot see." >&2
                     exit 1 ;;
                esac
              done
            "%
          ],
          # And that it actually analyses something.
          ["/bin/bash", "-c", "rz-bin -I /bin/rizin | grep -qi 'bintype'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      # Primary licence is LGPL-3.0-only (1813 SPDX headers), but the linked
      # binary aggregates a 16-licence REUSE union that includes GPL-3.0 and
      # GPL-2.0 files — so the shipped artifact is effectively GPL-3.0, and
      # recording the permissive core alone would understate it.
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rizinorg",
        repo = "rizin",
      },
    } | Attrs,
} | BuildSpec
