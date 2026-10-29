# herdr — terminal multiplexer / agent supervisor (herdr.dev).
#
# Replaces `curl -fsSL https://herdr.dev/install.sh | sh` in the agentbox image.
# That installer resolves herdr.dev/latest.json at run time and installs
# whatever it names, so two builds a day apart could silently differ.
#
# BUILT FROM SOURCE, not from the release binary. An earlier cut of this
# package pinned the published asset with upstream's own sha256, which proves
# the artifact did not change but says nothing about whether it matches this
# source. AGENTS.md is explicit: when the toolchain is packaged — and rust is —
# the package builds from the tarball. Same reasoning the rest of this bundle
# exists for.
#
# NO `needs` block, and no network: herdr ships Cargo.lock and the fetch layer
# pre-resolves crates before the sandbox. The vendored libghostty-vt's
# `zig build` DID reach the network, though: it downloaded eight zig packages
# at build time, and a reset from deps.files.ghostty.org failed an arm64 world
# rebuild (2026-10-29). Those eight are pinned below (`zig_deps`), mirrored to
# staging-archives, and seeded into zig's cache by build.sh; a guard there fails
# the build if zig fetches anything else.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
# herdr's vendored libghostty-vt requires exactly zig 0.16.0; `zig` is on 0.17
# (gominimal/pkgs#1148), so build against the prefixed zig-0.16 line. Move back
# to `zig` once herdr re-vendors the 0.17 ghostty.
let zig-0-16 = import "../zig-0.16/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.9.5" in
# The zig packages libghostty-vt's `-Demit-lib-vt` build actually fetches for
# herdr 0.9.5: measured by building with an in-tree ZIG_GLOBAL_CACHE_DIR and
# listing it (most of the 35 in its build.zig.zon files are lazy and unused).
# Upstream URLs are in vendor/libghostty-vt/{build.zig.zon,pkg/*/build.zig.zon};
# aro is translate-c's own dependency (github.com/vancluever/arocc @ f97cdfc3).
# build.sh checks each one's zig package hash against the one upstream pins.
# On a herdr bump: re-measure, and re-mirror whatever changed.
let zig_dep = fun file sha =>
  {
    url = "gs://minimal-staging-archives/herdr/zig-deps/%{file}",
    sha256 = sha,
  } | Source
in
let zig_deps = [
  zig_dep "arocc-f97cdfc3.tar.gz" "509e2f85b9464cd437fcec925b1cf1116f0d08218fe3ab4e74fa2c21173e7c57",
  zig_dep "ghostty-themes-release-20260831-151010-752a9c0.tgz" "83653eb837baeb5bfc7d50c91b7d44772796e08c1c243134e11c5edf6c8d15c5",
  zig_dep "highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz" "87d4f8893ef4e08f224973608ffebf94268a81380ba79c12e8841968c80aa212",
  zig_dep "pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz" "55e83b16d091082502bf149bf457f31f42092c5982650e3ffbae7b48871bf11a",
  zig_dep "translate-c-4e879eb8.tar.gz" "8fb0f5c6a3e8b3bf0e35225d3abc1230bcf6f1fdf162467f1f747ec2fa5eda07",
  zig_dep "uucode-2826a37a4562284fdacd8fa029d49509cc9bffcd.tar.gz" "7e76fc7fab1e7ac728c52b35bbb3e5b8c639841abfc7fe1a4bcb13050594bc9e",
  zig_dep "wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz" "17877d346f7988651d6c62e45b2e3b05c86809a6442c5e34612374b2a9719a1c",
  zig_dep "zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz" "17e88863f3600672ab49182f217281b6fc4d3c762bde361935e436a95214d05c",
]
in
{
  name = "herdr",
  build_deps =
    [
      { file = "build.sh" } | Local,
      {
        url = "https://github.com/herdrdev/herdr/archive/refs/tags/v%{version}.tar.gz",
        sha256 = "a2486b09a8153630f6a19e72606ba1c961a6194bce13c09cba67ccce5e4252de",
        extract = true,
        strip_prefix = "herdr-%{version}",
      } | Source,
      base,
      rust,
      zig-0-16,
      toolchain,
      make,
    ]
    @ zig_deps,
  cmd = "./build.sh",
  outputs = {
    herdr = { glob = "usr/bin/herdr" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "herdrdev", repo = "herdr" },
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec
