let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let git = import "../git/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

let version = "0.9.0" in
{
  name = "capy",
  build_deps = [
    { file = "build.sh" } | Local,
    # @capysc/cli source, hash-pinned and built from source (not the prebuilt
    # npm artifact). Referenced by url+sha256 — the source is never vendored
    # into this registry.
    {
      url = "https://github.com/capysc/capy-cli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "3257d7d0652d1df2e5d61cc1ed0e7313ac1e4d45a9ce62df4d2bc5e558f2de6a",
      extract = true,
      strip_prefix = "capy-cli-%{version}",
    } | Source,
    node-lts, # node + npm to build (tsc) and stage the CLI
  ],
  runtime_deps = [
    base,
    glibc,
    coreutils, # `capy` shebang resolves node via /usr/bin/env
    ca-certificates, # HTTPS to the Capy API (sync, decryption)
    git, # capy shells out to git for repo/branch detection
    node-lts, # capy is a Node CLI (#!/usr/bin/env node)
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # build.sh compiles the pinned source tarball above (tsc), then `npm install`
  # pulls the CLI's runtime deps from the registry — dns+internet cover that
  # dependency fetch. Follow-up: vendor the transitive npm deps as hash-pinned
  # Sources for a fully hermetic / SLSA build.
  needs = { dns = {}, internet = {} },

  outputs = {
    capy = { glob = "usr/bin/capy" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "AGPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "capysc",
        repo = "capy-cli",
      },
      # Maps the developer's ~/.capy into the box so in-box capy reuses the
      # existing login instead of transporting keys. Mounted read-write so capy
      # can refresh its session and update its local cache. For trusted
      # developer shells.
      env_dir_mappings = [{ read_only = false, path = "~/.capy", class = 'Credential }],
    } | Attrs,

  tests = {
    runs =
      {
        class = 'Standalone,
        test_deps = [base, node-lts],
        cmds = [
          # capy must run and report its version with no auth/network/config.
          ["/bin/bash", "-c", "capy --version | grep -q '%{version}'"],
        ],
      } | Test,
  },
} | BuildSpec
