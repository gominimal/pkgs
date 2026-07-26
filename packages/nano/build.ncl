let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let file = import "../file/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "9.1" in
{
  name = "nano",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nano-%{version}.tar.xz",
      sha256 = "5f47764274cb7532349ce0aa20ec10f1e8e851a6e9fa3eb66812c43d196db042",
      extract = true,
      strip_prefix = "nano-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    file,
    ncurses,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bin = { glob = "usr/bin/nano" } | OutputBin,
    languages = { glob = "usr/share/nano/*" } | OutputData,
    man = { glob = "usr/share/man/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GFDL-1.2-invariants-only AND GPL-3.0-only)",
      repology_project = "nano",
      source_provenance = {
        category = 'GnuProject,
        name = "nano",
      },
    } | Attrs,
} | BuildSpec
