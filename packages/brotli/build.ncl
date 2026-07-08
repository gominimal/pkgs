# Imported from Wolfi `brotli` by `pkgmgr import-wolfi` (cmake build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "1.2.0" in
{
  name = "brotli",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    make,
    pkgconf,
    toolchain,
    glibc,
    {
      url = "gs://minimal-staging-archives/google/brotli/v%{version}.tar.gz",
      sha256 = "816c96e8e8f193b40151dad7e8ff37b1221d019dbcb9c35cd3fadbfe6477dfec",
      extract = true,
      strip_prefix = "brotli-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    brotli = { glob = "usr/bin/brotli" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "google", repo = "brotli" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "brotli --help"],
          ["/bin/bash", "-c", "brotli --version"],
          ["/bin/bash", "-c", "echo \"Hello, Brotli compression test\" > original.txt\ncp original.txt copy.txt\nbrotli original.txt\ntest -f original.txt.br\nrm original.txt  # Remove original before decompressing\nbrotli --decompress original.txt.br\ndiff original.txt copy.txt"],
          ["/bin/bash", "-c", "echo \"Testing different compression levels\" > level_test.txt\nbrotli -q 1 level_test.txt -o level1.br\nbrotli -q 11 level_test.txt -o level11.br\ntest -f level1.br\ntest -f level11.br\nbrotli --decompress level1.br\nbrotli --decompress level11.br\ndiff level_test.txt level1\ndiff level_test.txt level11"],
          ["/bin/bash", "-c", "echo \"Testing stream compression\" > stream\ncat stream | brotli > stream.br\nbrotli --decompress < stream.br > stream_decoded\ndiff stream stream_decoded"],
        ],
      } | Test,
  },
} | BuildSpec
