let { BuildSpec, Local, Needs, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in

let node = import "../node/build.ncl" in

let version = "10.15.1" in
{
  name = "pnpm",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-%{version}.tgz",
      sha256 = "8c53af02ae3ec1fb0ae75377f8d4d6217c2d7cbe6f03c16350cabf7493de6eff"
    } | Source,
    base,
    tar,
  ],
  runtime_deps = [
    node,
  ],
  needs = {
    dns = {},
    internet = {},
  } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    pnpm = { glob = "usr/bin/pnpm" } | OutputBin,
    pnpx = { glob = "usr/bin/pnpx" } | OutputBin,

    libexec = { glob = "usr/libexec/pnpm/**" } | OutputLib,
  },
  attrs.upstream_version = version,
} | BuildSpec
