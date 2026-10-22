let { standaloneTest, upstream, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let zig = import "../zig/build.ncl" in

let version = "0.16.0" in
{
  name = "zls",
  # Zig language server, built from source with the zig package.
  # zls versions track zig minor versions; keep this in lockstep with
  # the upstream zig package (currently 0.16.0).
  #
  # Needs network: `zig build` fetches the dependencies declared in
  # build.zig.zon (known_folders, diffz, lsp_kit, ...), each verified
  # against the content hash pinned in that file.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/zigtools/zls/archive/refs/tags/%{version}.tar.gz",
      sha256 = "e7c5936f5b3a057ce851be0876e4e259b5c4d02f9aae038cd24a5d6b586b029f",
      extract = true,
      strip_prefix = "zls-%{version}",
    } | Source,
    base,
    zig,
  ],

  # No runtime deps: zls does not link libc, so the pinned-target build
  # in build.sh yields a fully static executable.
  runtime_deps = [],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    zls = { glob = "usr/bin/zls" } | OutputBin,
  },

  tests = {
    version = standaloneTest "zls --version",
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "zigtools",
        repo = "zls",
      },
    } | Attrs,
} | BuildSpec
