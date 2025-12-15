let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let variants = {
  "1.25.5" = {
    binaries_url = "https://go.dev/dl/go1.25.5.linux-amd64.tar.gz",
    binaries_sha256 = "9e9b755d63b36acf30c12a9a3fc379243714c1c6d3dd72861da637f336ebb35b",

    source_url = "https://go.dev/dl/go1.25.5.src.tar.gz",
    source_sha256 = "22a5fd0a91efcd28a1b0537106b9959b2804b61f59c3758b51e8e5429c1a954f",
  },
}
in
let version = "1.25.5" in
{
  name = "go",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = variants."%{version}".binaries_url,
      sha256 = variants."%{version}".binaries_sha256,
    } | Source,
    {
      url = variants."%{version}".source_url,
      sha256 = variants."%{version}".source_sha256,
    } | Source,
    base,
    toolchain,
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
    go_bin = { glob = "usr/bin/go" } | OutputBin,
    gofmt_bin = { glob = "usr/bin/gofmt" } | OutputBin,

    goroot = { glob = "usr/go/**/*" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "go",
  } | Attrs,
} | BuildSpec
