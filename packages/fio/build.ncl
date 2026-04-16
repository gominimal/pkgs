let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.42" in
{
  name = "fio",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/axboe/fio/archive/refs/tags/fio-%{version}.tar.gz",
      sha256 = "56b03497a918d07692257890fd759bf73168ad79df5be78a2bcbbdc8ce67895b",
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
    fio = { glob = "usr/bin/fio" } | OutputBin,
    fio2gnuplot = { glob = "usr/bin/fio2gnuplot", allow_missing_interpreter = true } | OutputBin,
    fio_generate_plots = { glob = "usr/bin/fio_generate_plots", allow_missing_interpreter = true } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "axboe",
        repo = "fio",
      },
    } | Attrs,
} | BuildSpec
