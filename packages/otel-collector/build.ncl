let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.150.1" in
{
  name = "otel-collector",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/open-telemetry/opentelemetry-collector-releases/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "082a7d78167336765461d95edf71127423dcff0399ccbc0963eb33d6f67e121b",
      extract = true,
      strip_prefix = "opentelemetry-collector-releases-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    otel-collector = { glob = "usr/bin/otelcol-contrib" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "open-telemetry",
        repo = "opentelemetry-collector-releases",
      },
    } | Attrs,
} | BuildSpec
