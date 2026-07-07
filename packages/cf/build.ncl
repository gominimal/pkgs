let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let node = import "../node/build.ncl" in

# cf is Cloudflare's unified CLI (technical preview). It is closed-source and
# distributed only as a pre-bundled npm package — there is no public source
# repository — so `source_provenance` is omitted (the schema only models
# GithubRepo/GnuProject/Sourceforge origins) and the registry tarball is pinned
# by sha256 below as the sole integrity/provenance anchor. `npm install` still
# reaches the registry for the single runtime dep (blake3-wasm, pinned to 2.1.5
# in cf's own package.json).
let version = "0.1.0" in
{
  name = "cf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/cf/-/cf-%{version}.tgz",
      sha256 = "758b65757a10cf6ef918c3ec02da45374d6b4ec402ebe39b6907e46b8ac25c1b",
    } | Source,
    base,
    node,
  ],
  runtime_deps = [
    coreutils,
    node,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cf = { glob = "usr/bin/cf" } | OutputBin,
    libexec = { glob = "usr/lib/node_modules/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,

  tests = {
    version_check = standaloneTest "/bin/cf --version",
  },
} | BuildSpec
