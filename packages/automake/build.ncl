let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let m4 = import "../m4/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "1.18.1" in
{
  name = "automake",
  inputs = [
    {
      url = "gs://minimal-staging-archives/automake-%{version}.tar.xz",
      sha256 = "168aa363278351b89af56684448f525a5bce5079d0b6842bd910fdd3f1646887"
    } | Source,
    { file = "build.sh" } | Local,
    autoconf,
    base,
    make,
    perl,
    m4,
    toolchain,
    zstd,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
    usr_share = { glob = "usr/share/**/*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
    repology_project = "automake",
  } | Attrs,
} | BuildSpec
