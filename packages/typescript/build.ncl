# Imported from npm `typescript` by `pkgmgr import npm` (node build).
# TODO: REVIEWER — installs `typescript` from npm; add any peer packages the
# tool needs (cf. typescript-language-server pulling `typescript`).
let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node = import "../node/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "7.0.2" in
{
  name = "typescript",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    base,
    node,
  ],
  runtime_deps = [coreutils, node],
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
    tsc = { glob = "usr/bin/tsc" } | OutputBin,
    libexec = { glob = "usr/libexec/typescript/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      # Arrived in #721 with no provenance, so the scan had no identity to
      # query and the coverage gate flagged it as a NEW no-cpe-hole on
      # 2026-09-22. Points at the upstream repo, which is what every other
      # npm-installed package here does (prettier -> prettier/prettier,
      # dotenvx -> dotenvx/dotenvx, opencode -> anomalyco/opencode). Tag
      # v7.0.2 upstream matches the version we ship.
      #
      # Deliberately NOT a `cpe_remap` entry for (microsoft, typescript). The
      # only advisory under that CPE pair is CVE-2020-1416 — "elevation of
      # privilege in Visual Studio and Visual Studio Code when they load
      # software dependencies" — which also names visual_studio_2017/2019/code
      # and carries NO version bounds. Mapping it here would attach a 2020
      # Visual Studio IDE bug to the compiler permanently, with no version that
      # could ever clear it: the unbounded-CPE false-positive class (cf. glibc).
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "TypeScript",
      },
    } | Attrs,
} | BuildSpec
