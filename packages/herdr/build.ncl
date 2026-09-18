let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# herdr — terminal multiplexer / agent supervisor (herdr.dev).
#
# Replaces `curl -fsSL https://herdr.dev/install.sh | sh` in the agentbox
# image. That installer resolves https://herdr.dev/latest.json at run time and
# fetches whatever it names, so the image could never be reproduced: two builds
# a day apart silently contain different binaries. The manifest's assets are
# plain GitHub release URLs and it publishes a sha256 per asset, so there is
# nothing to invent here — we pin the same artifact the installer would have
# picked and check the same digest it would have checked.
#
# The release ships a bare (unarchived) static binary per platform, hence no
# `extract`. Digests below are the manifest's own `sha256` entries for v0.9.1,
# re-verified against the GitHub assets.
let version = "0.9.1" in
let dl_base = "https://github.com/herdrdev/herdr/releases/download/v%{version}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "2a02fed16beb651ef006e1d43f048f652ca4dc58ad053cd2d44450563d5c54b7",
  arm64_sha256 = "f4ccf4de745f2cb9a39a983e9ba3703dad50ec2a58dea83026ceab721bbd8d9e",
}
in

{
  name = "herdr",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/herdr-linux-x86_64",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/herdr-linux-aarch64",
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
    bin = { glob = "usr/bin/herdr" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "herdrdev",
        repo = "herdr",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "%{dl_base}/herdr-linux-x86_64",
          { arch = 'Arm64, .. } => "%{dl_base}/herdr-linux-aarch64",
        } target,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/herdr --version | grep -q %{version}"],
        ],
      } | Test,
  },
} | BuildSpec
