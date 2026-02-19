let { Attrs, BuildSpec, Local, OutputBin, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.0" in
{
  name = "jqfmt",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/noperator/jqfmt/v%{version}.tar.gz",
      sha256 = "5435c3166921ea103513d516c4d56ee00755d6b0b798f3edbdabfc06a1d98268",
      extract = true,
      strip_prefix = "jqfmt-%{version}",
    } | Source,
    base,
    go,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    jqfmt = { glob = "usr/bin/jqfmt" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "noperator",
        repo = "jqfmt",
      },
    } | Attrs,
} | BuildSpec
