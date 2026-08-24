let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in

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
  # No runtime_deps: the installed binary is statically linked
  # (verified against the built tree, not assumed).

  cmd = "./build.sh",
  build_args = { include version, arch = target_suffix },

  outputs = {
    zvelte-check = { glob = "usr/bin/zvelte-check" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      # We install upstream's release BINARIES, not a build of the tree below.
      # `binary_from` is what says so; without it the package reads as
      # source-built from source_provenance, which is the exact conflation that
      # let chromium-bin look like a build of microsoft/playwright.
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://github.com/ampcode/zvelte-check/releases/download/v%{version}/zvelte-check-linux-x86_64.tar.gz",
          { arch = 'Arm64, .. } => "https://github.com/ampcode/zvelte-check/releases/download/v%{version}/zvelte-check-linux-aarch64.tar.gz",
        } target,
      # Kept alongside `binary_from`, as chromium-bin does. Here the two are the
      # SAME project — ampcode/zvelte-check builds these artifacts in its own
      # release workflow — so the repo is the honest identity of the bytes, and
      # dropping it would cost the CPE identity and the GitHub version-check
      # tier, i.e. make this a dark package. `closed_source` deliberately absent:
      # the repo is public and MIT with the Zig source in-tree (verified, not
      # inferred from the formula).
      source_provenance = {
        category = 'GithubRepo,
        owner = "ampcode",
        repo = "zvelte-check",
      },
    } | Attrs,
} | BuildSpec
