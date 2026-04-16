let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "12.4.3" in

let amd64_sha256 = "64707f35d54a5441ecbc63c0b3b633b7e73fe404fac118e88574f56d70b08a93" in
let arm64_sha256 = "825e31eb0aafcf026d7f04dd540042eedef42cb81a3d2832c296b27dacf7e95d" in

{
  name = "grafana",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://dl.grafana.com/oss/release/grafana-%{version}.linux-amd64.tar.gz",
          sha256 = amd64_sha256,
          extract = true,
          strip_prefix = "grafana-%{version}",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://dl.grafana.com/oss/release/grafana-%{version}.linux-arm64.tar.gz",
          sha256 = arm64_sha256,
          extract = true,
          strip_prefix = "grafana-%{version}",
        } | Source,
    } target,
    base,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    grafana = { glob = "usr/bin/grafana" } | OutputBin,
    grafana-server = { glob = "usr/bin/grafana-server" } | OutputBin,
    grafana-cli = { glob = "usr/bin/grafana-cli" } | OutputBin,
    public = { glob = "usr/share/grafana/public/**" } | OutputData,
    conf = { glob = "usr/share/grafana/conf/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "grafana",
        repo = "grafana",
      },
    } | Attrs,
} | BuildSpec
