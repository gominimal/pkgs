let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let openssl = import "../openssl/build.ncl" in
{
  name = "ca-certificates",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ssl-certs-complete-v2.tar.gz",
      sha256 = "72411982d730dda927844404cc803dab348548685ac95cbc6b73273abfc30257"
    } | Source,
    base-bootstrap,
    openssl,
  ],
  cmd = "./build.sh",
  outputs = {
    certs = { glob = "etc/ssl/certs/*" } | OutputData,
  },

  attrs =
    {
      license_spdx = "MPL-2.0",
      needed_for_internet = {},
    } | Attrs,
} | BuildSpec
