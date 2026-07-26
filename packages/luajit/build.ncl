let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# LuaJIT has no tagged releases (v2.1 is a rolling branch); this is the commit
# neovim 0.12.4 pins in its cmake.deps. The upstream version is
# 2.1.<timestamp> where the timestamp comes from the tarball's .relver file.
let commit = "fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac" in
let version = "2.1.1774638290" in
{
  name = "luajit",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/LuaJIT/LuaJIT/archive/%{commit}.tar.gz",
      sha256 = "e60cd2f3057aa39d33d1c895a20087ab54494d9a1ca45aa488ff0378af42df48",
      extract = true,
      strip_prefix = "LuaJIT-%{commit}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],
  cmd = "./build.sh",
  outputs = {
    luajit = { glob = "usr/bin/luajit" } | OutputBin,
    luajit_versioned = { glob = "usr/bin/luajit-*" } | OutputBin,
    libs = { glob = "usr/lib/libluajit*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    data = { glob = "usr/share/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "LuaJIT",
        repo = "LuaJIT",
      },
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "luajit -e 'print(jit.version)'"],
        ],
      } | Test,
  },
} | BuildSpec
