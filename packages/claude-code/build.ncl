let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let curl = import "../curl/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssh = import "../openssh/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let { version, amd64_sha256, arm64_sha256, gcs_bucket } = {
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
  version = "2.1.319",
  amd64_sha256 = "dabafec82ca1319fa43d8be36a10fc61b1d11821cb98ad5df04ad95e199b8eed",
  arm64_sha256 = "a7e687fd1cb054d651c7588223de3786c99d4c682365e3c3ae1e59ce7f3a591f",
}
in

{
  name = "claude-code",
  build_deps = [
    { file = "build.sh" } | Local,
    # Based on https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/bootstrap.sh
    #
    # - The current stable version is given by the string in the file at: $GCS_BUCKET/stable
    # - The manifest JSON for a version is $GCS_BUCKET/$version/manifest.json
    # - The actual binary is $GCS_BUCKET/$version/$platform/claude, where $platform is "$os-$arch" where $os in [linux, darwin] and arch in [x64, arm64].
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{gcs_bucket}/%{version}/linux-x64/claude",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{gcs_bucket}/%{version}/linux-arm64/claude",
          sha256 = arm64_sha256,
        } | Source,
    } target,
  ],
  runtime_deps = [
    base,
    coreutils,
    findutils,
    curl,
    git,
    glibc,
    ripgrep,
    openssh,
    # The wrapper defaults CLAUDE_CODE_CERT_STORE=system (CVE-2026-111943), so
    # the OS store must be present or Claude Code cannot reach its API.
    ca-certificates,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    claude = { glob = "usr/bin/claude" } | OutputBin,
    install = { glob = "usr/share/claude/versions/%{version}" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LicenseRef-Anthropic-Proprietary",
      # LICENSE.md: "© Anthropic PBC. All rights reserved. Use is subject to
      # Anthropic's Commercial Terms of Service." No redistribution grant.
      redistributable = false,
      binary_from = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
      closed_source = true,

      # Claude code wires `.claude.json`, which contains anthropic credentials for the user
      env_file_mappings = [{ read_only = false, path = "~/.claude.json", class = 'Credential }],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/claude --version",
  },
} | BuildSpec
