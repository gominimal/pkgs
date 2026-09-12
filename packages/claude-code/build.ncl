let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let curl = import "../curl/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssh = import "../openssh/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in

let { version, amd64_sha256, arm64_sha256, gcs_bucket } = {
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
  version = "2.1.233",
  amd64_sha256 = "55d281096f57d411ebbdd94dbf5e9ff3accb7c05713e37348c2c11d4b83bf9d9",
  arm64_sha256 = "42df1841f74e9b2ac13f2c1a2a820ef6b9ac5b2efb8646bb25c9a92b8bd69194",
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
      redistributable = false,
      binary_from = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
      closed_source = true,

      # Claude code wires `.claude.json`, which contains anthropic credentials for the user
      env_file_mappings = [{ read_only = false, path = "~/.claude.json", class = 'Credential }],
    } | Attrs,
} | BuildSpec
