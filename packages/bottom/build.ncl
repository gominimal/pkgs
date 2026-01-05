let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.12.3" in
{
  name = "bottom",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ClementTsang/bottom/archive/refs/tags/%{version}.tar.gz",
      sha256 = "1c70894f0eceb7034075959ff3080cf4706c11d7c012912c24e777abe4e62b70",
      extract = true,
      strip_prefix = "bottom-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    btm = { glob = "usr/bin/btm" } | OutputLib,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "bottom",
    } | Attrs,
} | BuildSpec
