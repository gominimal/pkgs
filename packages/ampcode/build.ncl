let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Imported from the Homebrew formula `ampcode/homebrew-tap/ampcode` by `pkgmgr import homebrew`.
#
# PREBUILT vendor binary — there is no source build. The pinned sha256
# per architecture is the ONLY integrity anchor for this package.
# TODO: REVIEWER — no source provenance derivable from the artifact URLs
#   (https://static.ampcode.com/cli/0.0.1784751724-g9d1cfb/amp-linux-x64);
#   the package will be UNSCANNABLE for vulnerabilities (0
#   advisories, permanently). Before accepting, search NVD for a CPE
#   naming THIS product
#   (services.nvd.nist.gov/rest/json/cpes/2.0?keywordSearch=<name>)
#   and record the result here either way. Do NOT attach a CPE for a
#   same-vendor but different product — that imports another
#   product's CVEs as false positives.
# TODO: REVIEWER — formula declares `license :cannot_represent` (proprietary). Emitted
#   as closed_source + redistributable=false, which the prod
#   buildbot ENFORCES (build-servers#180): the spec is excluded from
#   cache upload, exempted from the cache audit, and skipped in the
#   closure seal, so the artifact never enters the shared binary
#   cache. CONFIRM the vendor's terms still match that posture
#   before merging.
#
# ── TODO resolution (verified 2026-07-22) ───────────────────────────
# CPE: NVD keywordSearch=ampcode returns 0 results — no CPE identity
#   exists for Amp, so there is nothing to attach and this package is
#   UNSCANNABLE by construction, not by omission. Note `sourcegraph`
#   returns 462 CPEs, but every one is `sourcegraph:sourcegraph`, the
#   code-search product — a DIFFERENT product. Attaching it would import
#   another product's CVEs as false positives. Deliberately not done.
# TERMS: ampcode.com/terms grants a "limited, revocable, non-exclusive,
#   non-transferable, non-sublicensable" licence, so redistribution is
#   NOT permitted. Two mechanisms cover that, and both are real:
#     1. the Source urls fetch DIRECT from static.ampcode.com — the
#        artifact is never mirrored to gs:// in the first place;
#     2. `redistributable = false` is ENFORCED by the prod buildbot
#        (build-servers#180, merged 2026-07-21): excluded from cache
#        upload, exempt from the cache audit, skipped in the closure
#        seal. Consumers build locally via the index-miss fallback.
#
let version = "0.0.1784751724-g9d1cfb" in
let target_suffix = match { { arch = 'Amd64, .. } => "x64", { arch = 'Arm64, .. } => "arm64" } target in
{
  name = "ampcode",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://static.ampcode.com/cli/%{version}/amp-linux-x64",
          sha256 = "17b221d136cb0efc4593670953f80f13201c8c099eb53095b12e31f3ca572511",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://static.ampcode.com/cli/%{version}/amp-linux-arm64",
          sha256 = "2af77a636f9e2fd722ceb3405a9de1efd3729aff4f83d979bda98a7809566b9c",
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
    amp = { glob = "usr/bin/amp" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      closed_source = true,
      binary_from = "https://static.ampcode.com/cli/",
      redistributable = false,
    } | Attrs,
} | BuildSpec
