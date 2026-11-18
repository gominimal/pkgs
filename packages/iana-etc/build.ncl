let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in

let version = "20261110" in
{
  name = "iana-etc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iana-etc-%{version}.tar.gz",
      sha256 = "37c35ea7b0d2831e6d5c222ddba61af25cd7edb07a980a35581e04d359ebbb9f"
    } | Source,
    base,
  ],
  cmd = "./build.sh",
  outputs = {
    protocols = { glob = "etc/protocols" } | OutputData,
    services = { glob = "etc/services" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Mic92",
        repo = "iana-etc",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              test -s /etc/protocols && test -s /etc/services
              while read -r n p _; do [ "$n $p" = 'https 443/tcp' ] && exit 0; done < /etc/services; exit 1
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
