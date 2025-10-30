let { BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let node = import "../node/build.ncl" in
let ripgrep = import "../ripgrep/build.ncl" in

let { version, sha256, gcs_bucket } = {
  gcs_bucket = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases",
  version = "2.0.29",
  sha256 = "b49ac7493e3202ad97eca2f44b7552b0a5d5f3da7636749b867c6171da0d2f98",
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
} | BuildSpec
