# Auto-bootstrapped from https://github.com/tamarin-prover/tamarin-prover.
# tamarin-prover is a Haskell binary (security-protocol verifier). Upstream pins
# GHC 9.6 (Stack LTS 22.x); minimal ships GHC 9.10.3. Its .cabal files carry NO
# upper version bounds, so we drive it with `cabal` + the system GHC and let the
# solver pick 9.10-compatible Hackage versions. Pioneering — upstream hasn't
# published a 9.10 build (pkgmgr-rs#528).
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let cabal = import "../cabal/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let patch = import "../patch/build.ncl" in
let graphviz = import "../graphviz/build.ncl" in
let maude = import "../maude/build.ncl" in
let version = "1.12.0" in
{
  name = "tamarin-prover",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "fclabels-ghc910.patch" } | Local,
    # The Stackage LTS-24.50 cabal.config (~3.5k lines pinning the whole GHC-9.10.3
    # dep set) is FETCHED, not vendored: the pkgs repo is cloned by every consumer,
    # so we keep the large file out of it. It's an immutable Stackage snapshot,
    # pinned by sha256, and the build already needs internet for Hackage anyway.
    # (raised by @twitchyliquid64 on pkgs#449)
    {
      url = "gs://minimal-staging-archives/build-aux/stackage-lts-24.50.cabal.config",
      sha256 = "2014c4b51f8f5f9dcd0e5771619eff7c9d8d10cb205d22916e2c08b64ea8924c",
      extract = false,
    } | Source,
    {
      url = "https://github.com/tamarin-prover/tamarin-prover/archive/refs/tags/%{version}.tar.gz",
      sha256 = "35f0262e770db3632fcb297deb6ecc2d7c724c693fecfe97892e8224fa161956",
      extract = true,
      strip_prefix = "tamarin-prover-%{version}",
    } | Source,
    base,
    ghc,
    cabal,
    gmp,
    patch,
  ],
  runtime_deps = [
    gmp,
    graphviz,
    # tamarin shells out at runtime to Maude (the rewriting engine — its whole
    # backend) and GraphViz (`dot`, for proof visualisation). `tamarin-prover
    # test` exercises the Maude path. See pkgmgr-rs#528.
    maude,
  ],
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
    tamarin-prover = { glob = "usr/bin/tamarin-prover" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tamarin-prover",
        repo = "tamarin-prover",
      },
      # Huge Haskell build (~120 Hackage deps compiled from source).
      build_cost_multiple = 10,
    } | Attrs,
} | BuildSpec
