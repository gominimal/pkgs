let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in

let version = "20261027" in
{
  name = "iana-etc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iana-etc-%{version}.tar.gz",
      sha256 = "48981d07ab61179305abb9aa47ddbc50c7f0005ab0a4e08afd203fffad698873"
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
