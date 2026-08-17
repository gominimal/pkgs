let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Imported from the Homebrew formula `local/ampcode` by `pkgmgr import homebrew`.
#
# PREBUILT vendor binary — there is no source build. The pinned sha256
# per architecture is the ONLY integrity anchor for this package.
# TODO: REVIEWER — no source provenance derivable from the artifact URLs
#   (https://static.ampcode.com/cli/0.0.1784744899-ge9bc43/amp-linux-x64);
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
let version = "0.0.1784744899-ge9bc43" in
let target_suffix = match { { arch = 'Amd64, .. } => "x64", { arch = 'Arm64, .. } => "arm64" } target in
{
  name = "ampcode",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://static.ampcode.com/cli/%{version}/amp-linux-x64",
          sha256 = "04ea113582ffbf48cf9375bde451e75311c908364f17d49a4f94c0519566f087",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://static.ampcode.com/cli/%{version}/amp-linux-arm64",
          sha256 = "9cdcf4d50cf143f4af3dec60197ff508e01894408c3f4d727bef53fb904c45db",
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
