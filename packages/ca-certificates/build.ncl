let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let openssl = import "../openssl/build.ncl" in
# The Mozilla root store as extracted by curl: https://curl.se/docs/caextract.html
# Upstream: https://curl.se/ca/cacert-<YYYY-MM-DD>.pem (dated, immutable), checksum at
# https://curl.se/ca/cacert-<YYYY-MM-DD>.pem.sha256. Mirrored to staging byte-for-byte.
# The version is the bundle date with dots; the file name uses dashes.
let version = "2026.10.20" in
let date = std.string.replace "." "-" version in
{
  name = "ca-certificates",
  build_deps = [
    { file = "build.sh" } | Local,
    # Certificates/keys build.sh refuses to ship (CVE-2026-111943 and future incidents).
    { file = "distrust.txt" } | Local,
    # Fixtures for build.sh's chain tests. Build inputs only; none of them is installed.
    { file = "test-chain-emudhra-emsign.pem" } | Local,
    { file = "test-chain-emudhra-aaa.pem" } | Local,
    { file = "test-removed-roots.pem" } | Local,
    { file = "test-good-letsencrypt-r12.pem" } | Local,
    { file = "test-good-letsencrypt-e7.pem" } | Local,
    {
      url = "gs://minimal-staging-archives/cacert-%{date}.pem",
      sha256 = "796f1389bfea13c0ed78f663b765baaff54a508e5483786bd6ece73c5e3e3cbe"
    } | Source,
    base-bootstrap,
    openssl,
  ],
  cmd = "./build.sh",
  outputs = {
    certs = { glob = "etc/ssl/certs/*" } | OutputData,
    # OpenSSL's default CAfile (openssl is built --openssldir=/etc/ssl); a symlink to
    # certs/ca-certificates.crt. Nothing shipped it before, so default-store clients
    # without a CApath fallback had no roots.
    bundle = { glob = "etc/ssl/cert.pem" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
      needed_for_internet = {},
      source_provenance = {
        category = 'Website,
        homepage = "https://curl.se/docs/caextract.html",
        downloads_page = "https://curl.se/ca/",
      },
    } | Attrs,

  # build.sh already fails the build on a distrusted root, a compromised chain that
  # verifies, or a legitimate chain that doesn't. These check the INSTALLED tree.
  tests = {
    bundle_has_roots =
      {
        class = 'Standalone,
        test_deps = [bash, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "n=$(grep -c '^-----BEGIN CERTIFICATE-----$' /etc/ssl/certs/ca-certificates.crt) && test \"$n\" -ge 100"],
        ],
      } | Test,
    # CVE-2026-111943: neither root anchoring the compromised eMudhra intermediates may
    # be installed. The subject count guards against an empty parse passing the grep.
    emudhra_roots_absent =
      {
        class = 'Standalone,
        test_deps = [bash, coreutils, grep, openssl],
        cmds = [
          ["/bin/bash", "-c", "set -o pipefail; out=$(openssl crl2pkcs7 -nocrl -certfile /etc/ssl/certs/ca-certificates.crt | openssl pkcs7 -print_certs -noout) && test $(grep -c '^subject=' <<<\"$out\") -ge 100 && ! grep -E 'CN ?= ?(emSign ECC Root CA - G3|AAA Certificate Services)$' <<<\"$out\""],
          ["/bin/bash", "-c", "test ! -e /etc/ssl/certs/emSign_ECC_Root_CA_-_G3.crt && test ! -e /etc/ssl/certs/Comodo_AAA_Services_root.crt"],
        ],
      } | Test,
    # The hashed directory works (curl is built --with-ca-path=/etc/ssl/certs), and so
    # does openssl's built-in default store (/etc/ssl/cert.pem + /etc/ssl/certs).
    capath_lookup =
      {
        class = 'Standalone,
        test_deps = [bash, openssl],
        cmds = [
          ["/bin/bash", "-c", "openssl verify -no-CAfile -no-CAstore -CApath /etc/ssl/certs /etc/ssl/certs/ISRG_Root_X1.crt"],
          ["/bin/bash", "-c", "openssl verify -no-CApath -no-CAstore -CAfile /etc/ssl/cert.pem /etc/ssl/certs/ISRG_Root_X2.crt"],
          ["/bin/bash", "-c", "openssl verify /etc/ssl/certs/ISRG_Root_X1.crt"],
        ],
      } | Test,
  },
} | BuildSpec
