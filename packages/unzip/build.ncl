let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
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
    base,
    make,
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
