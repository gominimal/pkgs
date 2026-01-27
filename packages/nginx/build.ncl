let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in

let version = "1.28.1" in
{
  name = "nginx",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://nginx.org/download/nginx-%{version}.tar.gz",
      sha256 = "40e7a0916d121e8905ef50f2a738b675599e42b2224a582dd938603fed15788e",
      extract = true,
      strip_prefix = "nginx-%{version}",
    } | Source,
    bash,
    coreutils,
    grep,
    sed,
    make,
    binutils,
    gcc,
    linux_headers,
    zlib,
    openssl,
    pcre2,
  ],

  runtime_deps = [
    glibc,
    gcc,
    zlib,
    openssl,
    pcre2,
  ],

  cmd = "./build.sh",

  outputs = {
    nginx = { glob = "usr/bin/nginx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "nginx",
    } | Attrs,
} | BuildSpec
