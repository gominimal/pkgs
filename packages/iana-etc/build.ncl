let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let version = "20260723" in
{
  name = "iana-etc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iana-etc-%{version}.tar.gz",
      sha256 = "250a2ecd0e6e49e4f9cc31057d7f1119beeb9e459c50dd433966194e9a0a0ce0"
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
} | BuildSpec
