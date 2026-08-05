# Imported from npm `vlt` by `pkgmgr import npm` (node build).
#
# vlt is a package manager (vlt.sh), shipped as a single dependency-free npm
# tarball: `npm ci` installs exactly ONE package, pinned by version + integrity
# in the committed package-lock.json. No transitive tree, no native addons, no
# compile step — the whole build is an extract.
#
# WHY A REGISTRY ARTIFACT AND NOT A SOURCE BUILD — AGENTS.md requires this be
# called out explicitly, and the reason is not "nobody tried". Source IS
# published (codeload .../vltpkg/tar.gz/refs/tags/v1.0.1, 200, 7.4 MB, 48 real
# TypeScript workspaces). It cannot be built with a toolchain we have:
#
#   - The only lockfile in the repo is `vlt-lock.json` — vlt's own format.
#     There is no pnpm-lock.yaml and no package-lock.json.
#   - Dependency specs use the `catalog:` protocol with the catalog declared in
#     `vlt.json`. Measured against the extracted tarball:
#         npm  → EUNSUPPORTEDPROTOCOL: Unsupported URL Type "catalog:"
#         pnpm → ERR_PNPM_CATALOG_ENTRY_NOT_FOUND_FOR_SPEC (pnpm supports
#                catalogs, but reads pnpm-workspace.yaml, not vlt.json)
#     `package.json` has no `workspaces` key at all, so neither tool can even
#     see the monorepo layout.
#   - Upstream CI agrees: `uses: vltpkg/setup-vlt@v1` then `vlt install`.
#   - The published package (`infra/cli/package.json`) declares `bin: null`,
#     `dependencies: {}`, and one script — `prepack: vlt-build-prepack`. The
#     npm tarball is generated wholesale by their internal bundler.
#
# So building vlt from source requires vlt: a genuine bootstrap cycle, which is
# the "required toolchain genuinely isn't packaged yet" case AGENTS.md carves
# out. Breaking it would mean a two-stage `vlt-bootstrap` → `vlt` pair in the
# gawk-bootstrap shape; worth doing if vlt becomes load-bearing, not before.
#
# `node-lts`, not `node`, for both build and runtime. Two reasons, and the
# private `usr/libexec/vlt` prefix below is the third leg of the same argument
# (gominimal/pkgs#370: a global `usr/lib/node_modules` install collides with
# whichever node variant the user actually has):
#   - vlt's own CI tests Node 22.x only (`node-version: '^22.22.0'`, `[22.x]`)
#     and `engines` says `>=22.22.0`. Our node-lts is 24.14.1, node is 25.8.2 —
#     neither is 22.x, but LTS is two majors closer to what upstream tests.
#   - pnpm, the closest analogue in this repo (also a package manager, also a
#     node CLI), is on node-lts for exactly this reason — see #97/#98: the node
#     most users and hosting providers run is whatever ships with current LTS.
#
# Deliberately NO `source_provenance`. vlt's vuln identity is its npm package
# name, and minimal-supply-chain routes a node-flavored package with no
# provenance to `pkg:npm/<name>` (scan.rs `npm_purl_for_node_package`) so the
# OSV/GHSA npm advisories resolve. Declaring `GithubRepo vltpkg/vltpkg` would
# take it OFF that arm onto the repo-purl arm, where GHSA's npm advisories —
# which are keyed by package name, not repo — would no longer match. Absent is
# correct here, not an oversight.
let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.0.1" in
{
  name = "vlt",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    base,
    node-lts,
  ],
  runtime_deps = [coreutils, node-lts],
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
    # Enumerated, not `usr/bin/*`: the checker wants each bin named, and the
    # npm registry metadata already lists them exactly, so there is nothing to
    # infer. `vlt` is the CLI; the others are the documented shorthands
    # (`vlr` = `vlt run`, `vlx` = `vlt exec`, plus their variants).
    vlt = { glob = "usr/bin/vlt" } | OutputBin,
    vlr = { glob = "usr/bin/vlr" } | OutputBin,
    vlrx = { glob = "usr/bin/vlrx" } | OutputBin,
    vlx = { glob = "usr/bin/vlx" } | OutputBin,
    vlxl = { glob = "usr/bin/vlxl" } | OutputBin,

    libexec = { glob = "usr/libexec/vlt/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause-Patent",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/vlt --version",

    version_is_exact =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Exact equality, NOT `--version | grep '%{version}'`: vlt's usage
          # banner also carries the version ("next-gen package management
          # v1.0.1"), so a grep would pass on a build where `--version` itself
          # is broken and only usage prints. This asserts the artifact's own
          # version, independent of the build-time lockfile guard in build.sh.
          ["/bin/bash", "-c", "test \"$(/bin/vlt --version)\" = \"%{version}\""],
        ],
      }
        | Test,

    companion_bins_work =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Five bins are declared as outputs; they are PATH symlinks into the
          # private libexec prefix, so a broken relative link fails here and
          # nowhere else. A test that only exercised `vlt` would ship four
          # dead entries in usr/bin.
          ["/bin/bash", "-c", "for b in vlr vlrx vlx vlxl; do test \"$(/bin/$b --version)\" = \"%{version}\" || { echo \"$b failed\" >&2; exit 1; }; done"],
        ],
      }
        | Test,

    reads_a_manifest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Real work, offline: `vlt pkg get` parses a package.json and returns
          # a field. This exercises the bundled JS beyond argv handling — a
          # truncated or partially-installed tarball prints `--version` fine
          # and fails here. vlt has NO default registry as of 1.0.1, so any
          # network-touching command is not a candidate for a sandbox test.
          ["/bin/bash", "-c", "d=/tmp/vlt-selftest; mkdir -p \"$d\"; cd \"$d\"; printf '{\"name\":\"vlt-selftest-fixture\",\"version\":\"9.9.9\"}' > package.json; test \"$(/bin/vlt pkg get name)\" = '\"vlt-selftest-fixture\"'"],
        ],
      }
        | Test,
  },
} | BuildSpec
