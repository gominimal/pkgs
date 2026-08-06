let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "13.1.2" in

let amd64_sha256 = "2215a38a59b573f114128e05f3836cb8708ac9b04b9283021ad28fdb88d71290" in
let arm64_sha256 = "660cc31dbd159d98a3804ac5104b0aca0e0d95ee4e88a164ff63ddd72f9fda2e" in

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
      license_spdx = "AGPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "grafana",
        repo = "grafana",
      },
    } | Attrs,
} | BuildSpec
