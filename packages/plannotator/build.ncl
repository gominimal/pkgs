let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# plannotator — plan review / annotation tool (plannotator.ai).
#
# Replaces `curl -fsSL https://plannotator.ai/install.sh | bash` in the
# agentbox image. Of the three curl-pipe installers this one had the best story
# already: its releases carry SLSA build-provenance attestations from v0.17.2
# onward, publish a `.sha256` beside every asset, and ship a CycloneDX SBOM
# (`plannotator-<v>-release-sbom.cdx.json`). The digests below are that
# published `.sha256`, not something we computed and hoped matched.
#
# Bare static binary per platform — no archive, hence no `extract`.
let version = "0.27.16" in
let dl_base = "https://github.com/backnotprop/plannotator/releases/download/v%{version}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "dd332feb9af7428e0633ed7faa749ad91e89576b5a6daaae3880c1bcaefde116",
  arm64_sha256 = "0e9ccde99f0ec804e274d2d220f505a332ef66d32fdbb50361f932152e85807e",
}
in

{
  name = "plannotator",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/plannotator-linux-x64",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/plannotator-linux-arm64",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],

  runtime_deps = [
    glibc,
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
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "backnotprop",
        repo = "plannotator",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "%{dl_base}/plannotator-linux-x64",
          { arch = 'Arm64, .. } => "%{dl_base}/plannotator-linux-arm64",
        } target,
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
