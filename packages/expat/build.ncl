let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.7.5" in
{
  name = "expat",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/expat-%{version}.tar.xz",
      sha256 = "1032dfef4ff17f70464827daa28369b20f6584d108bc36f17ab1676e1edd2f91",
      extract = true,
      strip_prefix = "expat-%{version}",
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    xmlwf = { glob = "usr/bin/xmlwf" } | OutputBin,

    libexpat = { glob = "usr/lib/libexpat.so*" } | OutputLib,

    includes = { glob = "usr/include/expat*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/expat.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "expat",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libexpat",
        repo = "libexpat",
      },
    } | Attrs,
} | BuildSpec
