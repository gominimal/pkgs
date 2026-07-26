let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.8.2" in
{
  name = "expat",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/expat-%{version}.tar.xz",
      sha256 = "3ad89b8588e6644bd4e49981480d48b21289eebbcd4f0a1a4afb1c29f99b6ab4",
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
      license_spdx = "MIT",
      repology_project = "expat",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libexpat",
        repo = "libexpat",
      },
    } | Attrs,
} | BuildSpec
