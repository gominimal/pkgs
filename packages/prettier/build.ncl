# Imported from npm `prettier` by `pkgmgr import npm` (node build).
# TODO: REVIEWER — installs `prettier` from npm; add any peer packages the
# tool needs (cf. typescript-language-server pulling `typescript`).
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "3.9.8" in
{
  name = "prettier",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    base,
    node,
  ],
  runtime_deps = [coreutils, subsetOf node ["node"]],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    prettier = { glob = "usr/bin/prettier" } | OutputBin,
    libexec = { glob = "usr/libexec/prettier/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      # Advisory coverage, not download or version plumbing. Without this the
      # package had no identity an advisory source could reach and scanned
      # 0/0/0 — indistinguishable from genuinely clean (the monitoring-gap
      # alarm after pkgs#721).
      #
      # GithubRepo rather than a CPE curation because prettier has NO CPE
      # anywhere in prod advisory_cpe — zero rows for the product and zero
      # under pkg:npm/prettier — while pkg:github/prettier/prettier does hold
      # an advisory, and GithubRepo provenance is what resolves to that purl.
      #
      # Note `upstream_purl` is NOT the lever it looks like: it has zero
      # consumers in minimal-supply-chain or pkgmgr-rs, so setting it would
      # restore no coverage at all.
      #
      # Safe for version checking too: upstream tags are bare semver (3.9.8),
      # exactly the shape this package already pins, so provenance does not
      # mis-drive the upstream check.
      source_provenance = {
        category = 'GithubRepo,
        owner = "prettier",
        repo = "prettier",
      },
    } | Attrs,
} | BuildSpec
