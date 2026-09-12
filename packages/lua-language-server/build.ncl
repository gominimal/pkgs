let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let { target, .. } = import "config.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "3.19.1" in
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
          sha256 = "e9235d2d72ef55bc41cf8c99cda2ed64777682024b4bb81f5dea425060c5cbb8",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/LuaLS/lua-language-server/releases/download/%{version}/lua-language-server-%{version}-linux-arm64.tar.gz",
          sha256 = "abd2572e8fc929dc838a81ffb8473c5bce0bf39bfe8edb4b120b3b623176ce83",
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
