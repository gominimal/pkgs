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

let version = "1.31.3" in
{
  name = "nginx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://nginx.org/download/nginx-%{version}.tar.gz",
      sha256 = "a7657c50811c2d92d9895395e8b873ef60398142c4db21eb647811c38f6dd525",
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
      license_spdx = "BSD-2-Clause",
      repology_project = "nginx",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nginx",
        repo = "nginx",
      },
    } | Attrs,
} | BuildSpec
