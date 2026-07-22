let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Imported from the Homebrew formula `ampcode/homebrew-tap/zvelte-check` by `pkgmgr import homebrew`.
#
# PREBUILT vendor binary — there is no source build. The pinned sha256
# per architecture is the ONLY integrity anchor for this package.
let version = "0.2.0" in
let target_suffix = match { { arch = 'Amd64, .. } => "x86_64", { arch = 'Arm64, .. } => "aarch64" } target in
{
  name = "zvelte-check-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/ampcode/zvelte-check/releases/download/v%{version}/zvelte-check-linux-x86_64.tar.gz",
          sha256 = "f3326fe48a0a2bc056b16ce424abd705ca7864d3632fd8f02ace1ea8ecfc8b9b",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/ampcode/zvelte-check/releases/download/v%{version}/zvelte-check-linux-aarch64.tar.gz",
          sha256 = "05a2661648952ba12b2da618242698c3065d2db375340cb605288a38f59c4105",
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = { include version, arch = target_suffix },

  outputs = {
    zvelte-check = { glob = "usr/bin/zvelte-check" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ampcode",
        repo = "zvelte-check",
      },
    } | Attrs,
} | BuildSpec
