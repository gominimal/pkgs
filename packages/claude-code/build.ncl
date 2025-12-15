let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let node = import "../node/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in

let { version, sha256, gcs_bucket } = {
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
  version = "2.0.65",
  sha256 = "3a9e90f7f6a820f158a2e83977e916ca6ce6082ad80ff038ba129cf8e519637a",
}
in

{
  name = "claude-code",
  inputs = [
    { file = "build.sh" } | Local,
    # Based on https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/bootstrap.sh
    #
    # - The current stable version is given by the string in the file at: $GCS_BUCKET/stable
    # - The manifest JSON for a version is $GCS_BUCKET/$version/manifest.json
    # - The actual binary is $GCS_BUCKET/$version/$platform/claude, where $platform is "$os-$arch" where $os in [linux, darwin] and arch in [x64, arm64].
    {
      url = "%{gcs_bucket}/%{version}/linux-x64/claude",
      include sha256,
    } | Source,
    base,
  ],
  runtime_deps = [
    bash,
    glibc,
    ripgrep,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    claude = { glob = "usr/bin/claude" } | OutputBin,
    install = { glob = "usr/share/claude/versions/%{version}" } | OutputLib,
  },

  attrs = {
    upstream_version = version,

    # Claude code needs two things to function properly:
    #  - `.claude.json`, which contains anthropic credentials for the user
    #  - `.claude`, which contains project state and recent context windows and such.
    env_dir_mappings = [{read_only = false, path = "~/.claude", class = 'State}],
    env_file_mappings = [{read_only = false, path = "~/.claude.json", class = 'Credential}],
  } | Attrs,
} | BuildSpec
