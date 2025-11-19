let { BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let uv = import "../uv/build.ncl" in
{
  name = "diffoscope",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffoscope-306.tar.gz",
      sha256 = "eeaadcb5547edbb52045b0617be5ab5eda77a63d9a72ad1437b14ee84480c19f"
    } | Source,
    base,
    python,
    toolchain,
    uv,
  ],
  cmd = "./build.sh",
  outputs = {
    diffoscope = { glob = "usr/bin/diffoscope" } | OutputBin,
    site_packages = { glob = "usr/lib/python3.13/site-packages/**/*" } | OutputLib,
  },
} | BuildSpec
