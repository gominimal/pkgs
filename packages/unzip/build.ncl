let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.0" in
{
  name = "unzip",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "http://http.debian.net/debian/pool/main/u/unzip/unzip_6.0.orig.tar.gz",
      sha256 = "036d96991646d0449ed0aa952e4fbe21b476ce994abc276e49d30e686708bd37",
      extract = true,
      strip_prefix = "unzip60",
    } | Source,
    # Info-ZIP unzip 6.0 is frozen (2009); its CVE fixes live only in distro
    # patch-sets, so our effective security version is the Debian revision we
    # track, NOT the "6.0" upstream version. Apply Debian's full 6.0-31 series
    # (build.sh) to fix CVE-2014-8139/8140/8141/9636/9913, CVE-2015-7696/7697,
    # CVE-2016-9844, CVE-2018-1000035, CVE-2019-13232, CVE-2022-0529/0530,
    # CAN-2026-2034440/2034442/2034443 + build fixes. We stay on Info-ZIP (not
    # bsdunzip) because consumers like bun's build invoke `unzip -DD`, an
    # Info-ZIP-only flag bsdunzip lacks.
    #
    # Mirrored verbatim from Debian — this is their unpacked source overlay,
    # not a repack, so the sha256 below is exactly the one in Debian's
    # PGP-signed unzip_6.0-31.dsc and can be re-verified against it:
    #   https://deb.debian.org/debian/pool/main/u/unzip/unzip_6.0-31.dsc
    #
    # ⚠ This pin goes stale silently. Nothing in `pkgmgr check` watches Debian
    # revisions — upstream is frozen at 6.0, so the version checker reports us
    # current while the patch series falls behind. We shipped 6.0-29 for three
    # months while 6.0-30 and 6.0-31 carried three memory-safety fixes. When
    # touching this package, diff our series against Debian's current:
    #   curl -s https://deb.debian.org/debian/pool/main/u/unzip/ | grep debian.tar
    {
      url = "gs://minimal-staging-archives/unzip_6.0-31.debian.tar.xz",
      sha256 = "d7dc23f5254c6711dc05f467e70236cfd50a7931001c6152904474b19f295c38",
      extract = true,
    } | Source,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    funzip = { glob = "usr/bin/funzip" } | OutputBin,
    unzip = { glob = "usr/bin/unzip" } | OutputBin,
    unzipsfx = { glob = "usr/bin/unzipsfx" } | OutputBin,
    zipgrep = { glob = "usr/bin/zipgrep", allow_missing_interpreter = true } | OutputBin,
    zipinfo = { glob = "usr/bin/zipinfo" } | OutputBin,

    mans = { glob = "usr/share/man/man1/*.1" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Info-ZIP",
      repology_project = "unzip",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/unzip -v",

    roundtrip =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The package can extract a tiny zip archive built into this test:
          # just the bytes for a one-file zip containing "hello\n".
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
