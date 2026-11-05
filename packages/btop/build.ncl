let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "1.4.8" in
{
  name = "btop",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "gcc12-seed.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/aristocratos/btop/v%{version}.tar.gz",
      sha256 = "67e07c21b770a6d884c5e50ba1d2cfc90732ea57459367d8732ec7ecbeb3be5f",
      extract = true,
    } | Source,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [ncurses],
  cmd = "./build.sh",
  outputs = {
    btop = { glob = "usr/bin/btop" } | OutputBin,
    data = { glob = "usr/share/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "aristocratos",
        repo = "btop",
      },
    } | Attrs,
} | BuildSpec
