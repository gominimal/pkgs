let { BuildSpec, Local, OutputData, Prebuilt, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in

let version = "2.16.0" in
{
  name = "bash-completions",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/scop/bash-completion/releases/download/%{version}/bash-completion-%{version}.tar.xz",
      sha256 = "3369bd5e418a75fb990863925aed5b420398acebb320ec4c0306b3eae23f107a",
    } | Source,
    base,
    make,
    tar,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    etcs = { glob = "etc/**" } | OutputData,

    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },
  attrs.upstream_version = version,
} | BuildSpec
