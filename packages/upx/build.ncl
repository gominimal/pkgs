let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "5.2.0" in
{
  name = "upx",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    ninja,
    toolchain,
    glibc,
    {
      # The `-src` release asset, not the git tag: it ships the vendored
      # subprojects (ucl, lzma-sdk, zlib, zstd, bzip2, doctest) that are git
      # submodules in the repo and would otherwise be empty directories.
      #
      # NOT `extract = true`: upstream compresses this with an xz SHA-256
      # integrity check (`xz --list` reports `Check: SHA-256`, not the usual
      # CRC64), and the fetcher's decoder rejects it outright —
      #   compression error: Unsupported SHA-256 checksum (not yet implemented)
      # build.sh unpacks it with the system tar instead, which handles it.
      url = "https://github.com/upx/upx/releases/download/v%{version}/upx-%{version}-src.tar.xz",
      sha256 = "af99e526d5759de94412aea1104d5e4ca406cb725295f8633ecc9e843dc1ce1c",
    } | Source,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    upx = { glob = "usr/bin/upx" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
    docs = { glob = "usr/share/doc/**" } | OutputData,
  },
  # upx is C++, so it carries libstdc++/libgcc beyond glibc. Caught by the
  # `missing runtime_deps` checker rather than guessed: with only glibc here,
  # even `upx --version-short` died with
  #   error while loading shared libraries: libstdc++.so.6
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "upx", repo = "upx" },
      # The aggregate of what is actually LINKED INTO the shipped binary, which
      # is not the same as what sits in vendor/ — see build.sh for how that was
      # established:
      #   GPL-2.0-or-later  upx's own code, plus the vendored UCL
      #   Zlib              the vendored zlib
      #   MIT               doctest, compiled in via src/check/dt_impl.cpp
      # The vendored LZMA SDK is also compiled in (compress_lzma.cpp #includes
      # its .cpp files directly) but is placed in the PUBLIC DOMAIN by its
      # author, so it adds no conditions and has no SPDX identifier to add.
      # bzip2 and zstd are present in vendor/ but upstream hard-disables both
      # (CMakeLists.txt:269-270), so their licences are deliberately absent.
      #
      # UPX additionally grants a special exception so that compressing a
      # program does not impose the GPL on that program. That exception has no
      # SPDX identifier, so it cannot be expressed in this field — recorded
      # here instead, because the bare GPL value overstates the obligations on
      # anything this tool merely packs.
      license_spdx = "(GPL-2.0-or-later AND Zlib AND MIT)",
    } | Attrs,
  tests = {
    smoketest = standaloneTest "/bin/upx --version-short",

    # PACK, RUN, UNPACK, COMPARE — the only test that proves this package works.
    #
    # Everything cheaper is satisfied by a broken build. `upx --version` runs
    # without touching a single compressor. `upx --best foo` can produce a
    # file that is smaller and completely unrunnable, because the part that
    # has to be right is the decompression STUB that upx welds onto the front
    # of the output — per-architecture machine code, selected at pack time.
    # A stub that is missing or wrong for aarch64 yields an executable that
    # dies on exec, and nothing upstream of actually running it notices.
    #
    # So: pack a real binary, EXECUTE the packed copy and compare its output
    # to the original's, then unpack and compare bytes. This is upstream's own
    # self-pack test with the round-trip assertion made explicit.
    pack_run_unpack =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cp /usr/bin/upx /build/upx.orig

              # 1. It compresses at all.
              upx -q --best -o /build/upx.packed /build/upx.orig >/dev/null
              test -s /build/upx.packed

              # 2. ...and the result is genuinely smaller. A "packed" file that
              #    is the same size means upx fell back to storing.
              orig=$(stat -c%s /build/upx.orig)
              packed=$(stat -c%s /build/upx.packed)
              [ "$packed" -lt "$orig" ] || {
                echo "not compressed: $orig -> $packed" >&2; exit 1; }

              # 3. upx's own integrity check on the packed file.
              upx -q -t /build/upx.packed >/dev/null

              # 4. THE ONE THAT MATTERS: the packed binary still executes on
              #    this architecture, and behaves identically. This is what
              #    proves the decompression stub is right.
              a=$(/build/upx.orig --version-short)
              b=$(/build/upx.packed --version-short)
              [ "$a" = "$b" ] || {
                echo "packed binary misbehaved: '$a' vs '$b'" >&2; exit 1; }

              # 5. Unpacking restores the input BYTE FOR BYTE. Lossy
              #    decompression is the failure that would quietly corrupt a
              #    sample under analysis.
              upx -q -d -o /build/upx.unpacked /build/upx.packed >/dev/null
              cmp /build/upx.orig /build/upx.unpacked

              echo "PACK_RUN_UNPACK_OK $orig -> $packed" > /build/upx.result
              cat /build/upx.result
            "%
          ],
          # The marker must exist, so a script that dies early — or is
          # truncated — cannot pass by simply producing no output.
          ["/bin/bash", "-c", "grep -q '^PACK_RUN_UNPACK_OK ' /build/upx.result"],
        ],
      } | Test,
  },
} | BuildSpec
