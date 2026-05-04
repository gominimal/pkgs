let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let version = "20260424" in
{
  name = "iana-etc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/iana-etc-%{version}.tar.gz",
      sha256 = "93b3ed0e38c9d63fa65309d7fd811bec2aa5cbdeda983812e50b16bbc5eb01bb"
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "Mic92",
        repo = "iana-etc",
      },
    } | Attrs,
} | BuildSpec
