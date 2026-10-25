let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let { target, .. } = import "config.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "3.19.2" in
{
  name = "lua-language-server",
  # LuaLS (sumneko) language server, repackaged from the official
  # prebuilt Linux release tarballs.
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/LuaLS/lua-language-server/releases/download/%{version}/lua-language-server-%{version}-linux-x64.tar.gz",
          sha256 = "93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/LuaLS/lua-language-server/releases/download/%{version}/lua-language-server-%{version}-linux-arm64.tar.gz",
          sha256 = "17b8e401a874440adeb649e5024c364f2bb9d15156c74a40e56d1ae9a1b2e4f2",
        } | Source,
    } target,
    base,
    tar,
  ],

  runtime_deps = [
    base,
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    lua-language-server = { glob = "usr/bin/lua-language-server" } | OutputBin,
    install = { glob = "usr/share/lua-language-server/**", allow_data = true } | OutputLib,
  },

  tests = {
    version = standaloneTest "lua-language-server --version",
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      binary_from = "https://github.com/LuaLS/lua-language-server/releases",
    } | Attrs,
} | BuildSpec
