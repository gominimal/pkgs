let { BuildSpec, Local, Needs, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "uv",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/uv-0.9.3.tar.gz",
      sha256 = "79246789f62f62886815d647af39760c8fe9ab0724f149e02f397b85cf35428b"
    } | Source,
    base,
    make,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  outputs = {
    minimal = { glob = "usr/bin/uv" } | OutputLib,
  },
} | BuildSpec
