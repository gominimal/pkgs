let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# antigravity — Google's Antigravity CLI.
#
# Replaces `curl -fsSL https://antigravity.google/cli/install.sh | bash` in the
# agentbox image. That installer queries an auto-updater service
# (`.../manifests/<platform>.json`) and installs whatever it currently names,
# so the image is not reproducible across builds.
#
# ⚠ THE VERSION ALONE DOES NOT DETERMINE THE URL. The artifact path embeds a
# build id that is not derivable from the version:
#
#     .../antigravity-cli/1.2.6-5912685477494784/linux-x64/cli_linux_x64.tar.gz
#                        ^^^^^ ^^^^^^^^^^^^^^^^
#                      version   build id
#
# So this package CANNOT be bumped by rewriting `version` — the updater would
# produce a 404. A bump has to re-read the manifest for the new build id. That
# is the one real cost of packaging this, and it is still cheaper than shipping
# an unpinned installer. Manifests:
#   https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
#   https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_arm64.json
#
# ⚠ NO source_provenance, and `closed_source = true` in attrs. The artifact is
# a Google-hosted binary with no public source repo and no CPE, so there is
# nothing to scan against — the same position as claude-code, which is packaged
# identically (per-arch prebuilt from a vendor GCS bucket, LicenseRef-* license,
# closed_source set). The flag is what distinguishes "proprietary by nature"
# from "someone forgot the provenance"; without it this reads as an accidental
# dark package. If a repo or CPE ever appears, wire it up.
#
# Not packageable from source: no public repo exists, and the npm names are
# squatters — `antigravity` 0.0.0 ("placeholder for the haters", imlucas) and
# `antigravity-cli` 0.0.1 (joseph.chiang). Neither is Google.
#
# Upstream publishes sha512 in the manifest; `Source` takes sha256, so the
# digests below were computed from the exact artifacts the manifest named and
# should be re-derived the same way on any bump.
let version = "1.2.6" in
let build_id = "5912685477494784" in
let dl_base = "https://storage.googleapis.com/antigravity-public/antigravity-cli/%{version}-%{build_id}" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "3d4973187c4c074e70894068053eeef1b7dfa9c0a16bfe9c3b81954de0d2cc5c",
  arm64_sha256 = "02a0a2c863113f89ac684226ef81de47b9865238fac1076e8f9aea7ec5f4914a",
}
in

{
  name = "antigravity",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/linux-x64/cli_linux_x64.tar.gz",
          sha256 = amd64_sha256,
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/linux-arm/cli_linux_arm64.tar.gz",
          sha256 = arm64_sha256,
          extract = true,
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
    include build_id,
  },

  outputs = {
    bin = { glob = "usr/bin/antigravity" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      # LicenseRef-* because there is no SPDX id and no licence text ships:
      # the tarball contains exactly one member (the binary). The evidence for
      # calling it proprietary is in the binary itself — it carries the strings
      # "Terms of Service & Data Use" and "All rights reserved" — and there is
      # no public source repo (googlesource 404s; google/antigravity,
      # google-gemini/antigravity-cli and googleapis/antigravity are all 404).
      license_spdx = "LicenseRef-Google-Antigravity-CLI-ToS",
      # Marks this as a deliberately closed-source prebuilt rather than a
      # package that merely forgot its provenance — the same posture
      # claude-code uses. Without it this reads as an accidentally dark
      # package in the coverage reports.
      closed_source = true,
      binary_from =
        match {
          { arch = 'Amd64, .. } => "%{dl_base}/linux-x64/cli_linux_x64.tar.gz",
          { arch = 'Arm64, .. } => "%{dl_base}/linux-arm/cli_linux_arm64.tar.gz",
        } target,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "LD_BIND_NOW=1 /bin/antigravity --version"],
        ],
      } | Test,
  },
} | BuildSpec
