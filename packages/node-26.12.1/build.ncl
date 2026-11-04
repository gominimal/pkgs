let { subsetOf, Attrs, BuildSpec, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let icu = import "../icu/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
# node-26.12.1: the node that regenerates `node`'s bundled JavaScript, from gen-14 of
# gominimal/bootstrap: node 26.12.1 as shipped with its wasm blobs rebuilt from source, then
# rebuilt with its bundled JavaScript regenerated, each reproduced byte for byte on two
# independent machines per arch before publishing (generations/gen-14/manifest.json). Every
# library node bundles is built from deps/; ICU is the system one.
let version = "26.12.1" in
{
  name = "node-26.12.1",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-14/sha256/90c146ac13a17064d83709c535942083c85a155c3c04dc1fe9fa4d786b817ca9/node-26.12.1-x86_64.tar.zst",
          sha256 = "90c146ac13a17064d83709c535942083c85a155c3c04dc1fe9fa4d786b817ca9",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-14/sha256/13d4dc6d3114c035823cbb7e67c42fff3f74b30f1e58d301166c8192b26bb661/node-26.12.1-aarch64.tar.zst",
          sha256 = "13d4dc6d3114c035823cbb7e67c42fff3f74b30f1e58d301166c8192b26bb661",
          extract = true,
        } | Source,
    } target,
  ],
  runtime_deps = [
    coreutils, # npx/npm need /usr/bin/env
    icu,
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    # node trusts OpenSSL's default store, /etc/ssl
    ca-certificates,
  ],
  outputs = {
    node = { glob = "usr/bin/node" } | OutputBin,
    npx = { glob = "usr/bin/npx" } | OutputBin,
    npm = { glob = "usr/bin/npm" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    buildinfo = { glob = "usr/share/node/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nodejs",
        repo = "node",
      },
    } | Attrs,
} | BuildSpec
