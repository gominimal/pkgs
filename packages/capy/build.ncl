let { Attrs, BuildSpec, Local, OutputBin, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let git = import "../git/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

let version = "0.6.1" in
{
  name = "capy",
  build_deps = [
    { file = "build.sh" } | Local,
    node-lts, # node + npm to install the package
  ],
  runtime_deps = [
    base,
    glibc,
    coreutils, # `capy` shebang resolves node via /usr/bin/env
    ca-certificates, # HTTPS to the Capy API (sync / co-decrypt)
    git, # capy shells out to git for repo/branch detection
    node-lts, # capy is a Node CLI (#!/usr/bin/env node)
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # npm fetches @capysc/cli + its deps from the registry during the build.
  # Follow-up: vendor the tarball + transitive deps as hash-pinned Sources for a
  # fully hermetic / SLSA build.
  needs = { dns = {}, internet = {} },

  outputs = {
    capy = { glob = "usr/bin/capy" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # 1a shared-session model: pinhole the host ~/.capy into the box so in-box
      # capy reuses the developer's existing login (no key transport). rw because
      # capy refreshes its session and writes caches. Exposes the full host
      # session to the box: trusted dev shells only, never untrusted agent tasks.
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
