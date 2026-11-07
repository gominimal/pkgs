let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let git = import "../git/build.ncl" in
let bun = import "../bun/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let jq = import "../jq/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# plannotator — plan review / annotation tool (plannotator.ai).
#
# Replaces `curl -fsSL https://plannotator.ai/install.sh | bash` in the agentbox
# image, which installs whatever the "latest" tag currently resolves to.
#
# BUILT FROM SOURCE. An earlier cut of this package pinned the published
# release binary using upstream's own .sha256. That is a strong integrity
# claim — the releases even carry SLSA build-provenance attestations and a
# CycloneDX SBOM — but it still only proves the artifact did not change, not
# that it corresponds to this source. AGENTS.md requires a source build when
# the toolchain is packaged, and bun is.
#
# The build steps mirror upstream's own release.yml exactly (install with the
# frozen lockfile, build the review + hook UI, then `bun build --compile` the
# hook server entrypoint). Deviating from that is how you ship something that
# is not the tool people expect. The deliberate deviations (compile target,
# --ignore-scripts, the fallback guides.show viewer pin instead of a rebuilt
# one, no release telemetry mark) are each explained in build.sh.
#
# `needs` is set because `bun install` fetches from the npm registry.
let version = "0.28.50" in

{
  name = "plannotator",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/backnotprop/plannotator/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "39ab011073eaf2866ecfa8ca395143bdfeb5d29fa5c464a20c2633e4163f57bc",
      extract = true,
      strip_prefix = "plannotator-%{version}",
    } | Source,
    base,
    bun,
    jq,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    # plannotator reviews plans against a working tree and invokes git.
    git,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bin = { glob = "usr/bin/plannotator" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      # Upstream README: "Dual-licensed under Apache 2.0 or MIT at your option"
      # (LICENSE-APACHE + LICENSE-MIT). GitHub's repo metadata shows only
      # Apache-2.0 because it reads one file.
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "backnotprop",
        repo = "plannotator",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/plannotator --version"],
        ],
      } | Test,
  },
} | BuildSpec
