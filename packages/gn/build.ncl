let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# gn — Google's meta-build system generator (generates ninja files).
# Packaged as a chromium-from-source build prerequisite (pkgmgr-rs#681):
# the official chromium tarball ships only an x86-64 prebuilt gn, so the
# arm64 build needs a system gn either way, and a package beats
# re-bootstrapping it inside every chromium build.
#
# Versioning: upstream has NO releases or tags beyond `initial-commit`;
# its version IS the commit position — `gn --version` prints
# "<position> (<12-char sha>)", derived from `git describe`. We follow
# Gentoo's scheme: version 0.<position>. Source is a `git archive` of
# that commit mirrored to gs:// — gitiles' own /+archive/ tarballs are
# generated on the fly and NOT byte-stable, so they can never be
# sha256-pinned directly. Bumping = new archive from a newer commit,
# update `version` here AND the position/sha pinned in build.sh.
#
# ⚠ Version-tracking: update-dark for now. Upstream is
# gn.googlesource.com (no provenance category fits), and repology's
# `gn` project is all-`noscheme` (each distro invents its own scheme:
# dates, short hashes, positions) so `repology_project` would propose
# garbage. The clean fix is a curated NAME_KEYED_VERSION_CHECK entry in
# pkgmgr-rs reading the gitiles API for the latest commit position —
# tracked as a follow-up on pkgmgr-rs#681.
let version = "0.2511" in
{
  name = "gn",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gn/gn/%{version}.tar.gz",
      sha256 = "3e85ceeb08cdb563a5db995175f9e5173a337f7e0b4822078f514a0bb7c991bf",
      extract = true,
      strip_prefix = "gn-%{version}",
    } | Source,
    base,
    python,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    gn = { glob = "usr/bin/gn" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
    } | Attrs,

  tests = {
    # Pins the version header wired in build.sh: `gn --version` must
    # print the pinned commit position, not 0 (UNKNOWN) — the tarball
    # has no .git, so a silent fallback would ship a gn that lies about
    # what it is.
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/gn --version | grep -q '^2511 '"],
        ],
      } | Test,
  },
} | BuildSpec
