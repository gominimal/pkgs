let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "13.3.2" in

let amd64_sha256 = "e6f06cf4ad96a4809294c2e78d3ebe6bc42a79bff36ffe35eefbe502fc19aa87" in
let arm64_sha256 = "366f33263bf92a615644b129cb1f465eb32d632e48c6157c1831ca0194385a56" in

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

  tests = {
    # The package had NO tests until the 12.4.3 -> 13.1.2 bump failed at
    # `install: cannot stat 'bin/grafana-server'`. That failure was loud only
    # because build.sh runs with `set -e`; the shape it belongs to — upstream
    # changing which binaries a tarball ships — is otherwise invisible until a
    # user runs the missing command.
    smoketest = standaloneTest "/bin/grafana --version",

    subcommands_replace_the_dropped_bins =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          # `grafana-server` and `grafana-cli` are gone as of 13. Assert the
          # subcommands that replaced them actually exist, so "we dropped two
          # bins" can never quietly become "we dropped the functionality".
          ["/bin/bash", "-c", "/bin/grafana server --help >/dev/null"],
          ["/bin/bash", "-c", "/bin/grafana cli --help >/dev/null"],
        ],
      }
        | Test,
  },
} | BuildSpec
