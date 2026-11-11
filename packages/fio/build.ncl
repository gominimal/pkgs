let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.43" in
{
  name = "fio",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/axboe/fio/archive/refs/tags/fio-%{version}.tar.gz",
      sha256 = "efa49b3f36eda9adf29294f27a87d7e457747d676cd0f73996d6365357832cfe",
      extract = true,
      strip_prefix = "fio-fio-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # fio plus the 7 SCRIPTS its install target copies (python and sh).
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,
    # gnuplot templates fio2gnuplot reads.
    gpm = { glob = "usr/share/fio/*.gpm" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "axboe",
        repo = "fio",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/fio --version",
  },
} | BuildSpec
