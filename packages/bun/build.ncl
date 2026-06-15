let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let rust = import "../rust/build.ncl" in
let go = import "../go/build.ncl" in
let python = import "../python/build.ncl" in
let ruby = import "../ruby/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let git = import "../git/build.ncl" in
let curl = import "../curl/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.13" in
let dl_base = "https://github.com/oven-sh/bun/releases/download/bun-v%{version}" in
let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "79c0771fa8b92c33aae41e15a0e0d307ea99d0e2f00317c71c6c53237a78e25a",
  arm64_sha256 = "70bae41b3908b0a120e1e58c5c8af30e74afae3b8d11b0d3fdd8e787ddfb4b22",
}
in
{
  name = "bun",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz",
      sha256 = "8cd7b2fd45df28546155f921541c35d2df265a591483853c7c54961ddfbcef7c",
      extract = true,
      strip_prefix = "bun-bun-v%{version}",
    } | Source,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/bun-linux-x64.zip",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/bun-linux-aarch64.zip",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
    toolchain,
    cmake,
    ninja,
    llvm,
    rust,
    go,
    python,
    ruby,
    perl,
    pkgconf,
    make,
    git,
    curl,
    automake,
    libtool,
    unzip,

    # Pre-staged vendor deps (discovered via `orch discover-bun --remote`).
    # bun's scripts/build/deps/*.ts declare each as a github-archive ref;
    # without these, bun's fetch-cli.ts hits the network at build time.
    # extract=false: bun's own fetch-cli does the extract — we just need
    # the tarball at a path build.sh can find (it copies to bun's tarball
    # cache so bun short-circuits its download).
    #
    # #47 ROOT-CAUSE FIX: bun's npm INSTALL cache (distinct from the C-dep fetch
    # cache) covering ALL 3 bun_install ninja edges (root + packages/bun-error +
    # src/node-fallbacks). Without it the offline build's `bun install` issues a
    # blackholed registry connect() -> do_epoll_wait hang forever. Built by bun
    # 1.3.13 + validated offline (3/3 edges, --no-dns 2026-06-14). build.sh
    # extracts it into BUN_INSTALL_CACHE_DIR (=/state/bun-cache). extract=false.
    {
      url = "https://minimal.dev/generated/bun-install-cache-%{version}.tar.gz",
      sha256 = "0337827fb8792146b0aef151083a50da81b97ed9aba5f4fa13bb3d75eec09147",
      extract = false,
    } | Source,
    # #47 (ALL 3 install edges): a COLD `bun install --frozen-lockfile` ALWAYS
    # contacts the registry for metadata even with BUN_INSTALL_CACHE_DIR populated
    # (proven by run #5/image 386b0316: root no-op'd from its pre-staged node_modules,
    # but the bun-error edge still hung at [643/669] despite the cache). The ONLY way
    # an install touches no network is a pre-existing, lockfile-matching node_modules.
    # This tarball carries ALL THREE: root (232 pkgs incl the github/codeload dep
    # bun-tracestrings) + packages/bun-error (preact) + src/node-fallbacks (esbuild …).
    # Built by bun 1.3.13; build.sh extracts relative to /build so each lands under its
    # source dir, making every bun_install edge a no-op verify. extract=false.
    {
      url = "https://minimal.dev/generated/bun-allnm-%{version}.tar.gz",
      sha256 = "afbea83c7519928318206976b19f03233495342d83da293f72474f91536f7161",
      extract = false,
    } | Source,
    {
      url = "https://github.com/ebiggers/libdeflate/archive/c8c56a20f8f621e6a966b716b31f1dedab6a41e3.tar.gz",
      sha256 = "1e5cc06bdbf3e1245d8b89c9e3588f507e3c8bc53fe8b8229770a9e8661dea81",
      extract = false,
    } | Source,
    {
      url = "https://github.com/h2o/picohttpparser/archive/066d2b1e9ab820703db0837a7255d92d30f0c9f5.tar.gz",
      sha256 = "637ff2ab6f5c7f7e05a5b5dc393d5cf2fea8d4754fcaceaaf935ffff5c1323ee",
      extract = false,
    } | Source,
    {
      url = "https://github.com/facebook/zstd/archive/f8745da6ff1ad1e7bab384bd1f9d742439278e99.tar.gz",
      sha256 = "4b0bd1f0cfb25e61b9103c35f27395530ff5b4c0d2513a00fd745849e85ea52c",
      extract = false,
    } | Source,
    {
      url = "https://github.com/litespeedtech/ls-hpack/archive/8905c024b6d052f083a3d11d0a169b3c2735c8a1.tar.gz",
      sha256 = "07d8bf901bb1b15543f38eabd23938519e1210eebadb52f3d651d6ef130ef973",
      extract = false,
    } | Source,
    {
      url = "https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz",
      sha256 = "e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff",
      extract = false,
    } | Source,
    {
      url = "https://github.com/cloudflare/lol-html/archive/77127cd2b8545998756e8d64e36ee2313c4bb312.tar.gz",
      sha256 = "2c53161edf633fa99acfc4eafddbafd5d9b8199f0918a1cc9152cb6c2c9bf379",
      extract = false,
    } | Source,
    {
      url = "https://github.com/google/highway/archive/ac0d5d297b13ab1b89f48484fc7911082d76a93f.tar.gz",
      sha256 = "a7a816f4b62a0414ff0d39c0a8875847468dd6f7c9ad71781a24469a756cdea7",
      extract = false,
    } | Source,
    {
      url = "https://github.com/libuv/libuv/archive/f3ce527ea940d926c40878ba5de219640c362811.tar.gz",
      sha256 = "46040d51e8aa86a7c84e377e224d427c35022ec6e3ed8ed399493b0d8574d0cf",
      extract = false,
    } | Source,
    {
      url = "https://github.com/oven-sh/tinycc/archive/12882eee073cfe5c7621bcfadf679e1372d4537b.tar.gz",
      sha256 = "6b50485fcbbfa90a99c56e8e2b6a92014dcd34377d5edb23e1938dc9ec96f0aa",
      extract = false,
    } | Source,
    {
      url = "https://github.com/zlib-ng/zlib-ng/archive/12731092979c6d07f42da27da673a9f6c7b13586.tar.gz",
      sha256 = "a0d2a5d122c84b56a793a1553a9c3327fb2eb7469bf7a86b79e3c7be5d92e8d6",
      extract = false,
    } | Source,
    {
      url = "https://github.com/oven-sh/boringssl/archive/0c5fce43b7ed5eb6001487ee48ac65766f5ddcd1.tar.gz",
      sha256 = "a414b1d105fef105697b7428c0be5f7fc67489849eaa276931ae8344d78a99b8",
      extract = false,
    } | Source,
    {
      url = "https://github.com/oven-sh/mimalloc/archive/57029fb1f193e633462e76af745599e1dbfd4b58.tar.gz",
      sha256 = "6638fdefae72543d71689da896b68095c1123fcbbc517c5b7d9e33a316317f5b",
      extract = false,
    } | Source,
    {
      url = "https://github.com/c-ares/c-ares/archive/3ac47ee46edd8ea40370222f91613fc16c434853.tar.gz",
      sha256 = "8c94116cb366ae4a44e487da4d9f7e736287d329efa6f88fdf077cd2d0a2e4b8",
      extract = false,
    } | Source,
    {
      url = "https://github.com/HdrHistogram/HdrHistogram_c/archive/be60a9987ee48d0abf0d7b6a175bad8d6c1585d1.tar.gz",
      sha256 = "811c5e5ae5303a75ade50688880af6aad5d2f951ec5785f68186bd18635cdfc9",
      extract = false,
    } | Source,
    {
      url = "https://github.com/libarchive/libarchive/archive/ded82291ab41d5e355831b96b0e1ff49e24d8939.tar.gz",
      sha256 = "042f0efe7147063ff9ba10f1a38ed080e949bcbd04bdbf3592b8846dd11b1da2",
      extract = false,
    } | Source,
    {
      url = "https://nodejs.org/dist/v24.3.0/node-v24.3.0-headers.tar.gz",
      sha256 = "045e9bf477cd5db0ec67f8c1a63ba7f784dedfe2c581e3d0ed09b88e9115dd07",
      extract = false,
    } | Source,
    {
      # NON-LTO: bun build:release fetches bun-webkit-linux-amd64.tar.gz
      # (cache key webkit-<commit[:16]>, no -lto suffix) — confirmed from
      # the build log 2026-05-30. discover-bun previously picked -lto;
      # build.sh seeds this into the non-lto dest+identity.
      url = "https://github.com/oven-sh/WebKit/releases/download/autobuild-4d5e75ebd84a14edbc7ae264245dcd77fe597c10/bun-webkit-linux-amd64.tar.gz",
      sha256 = "14c6f7c7feaf007a492f186d8c1fc6a05193390c6aa5eddc2833997ae29c7ee1",
      extract = false,
    } | Source,
    {
      url = "https://github.com/oven-sh/zig/releases/download/autobuild-365343af4fc5a1a632e6b54aadd0b87be30edd81/bootstrap-x86_64-linux-musl.zip",
      sha256 = "05a7adbb958116a014c7faadbdfb1e990a5ce8941124a91c548f45d2bf0d0d38",
      extract = false,
    } | Source,
    # lolhtml's c-api builds via cargo. Its 43-crate dep set (encoding_rs,
    # …) `cargo vendor`-ed from c-api/Cargo.lock @77127cd2, mirrored to
    # CAS. build.sh extracts it + redirects crates.io to it (offline) so
    # the cargo build needs no network. The ONLY cargo sub-crate in bun.
    {
      url = "https://storage.googleapis.com/minimalmertic-hermetic-mirror/sha256/3654cc353be6a67a194ee437f5a0f335604d3259c5d3c3255c968b2cd2bf3672/lolhtml-capi-vendor.tar.zst",
      sha256 = "3654cc353be6a67a194ee437f5a0f335604d3259c5d3c3255c968b2cd2bf3672",
      extract = false,
    } | Source,
  ],
  runtime_deps = [
    glibc,
    git,
  ],
  # Hermetic: build.sh seeds bun's tarball cache from the 18 pre-staged
  # Source deps above, so bun's fetch-cli.ts short-circuits its github
  # downloads. No network needed at build time.
  needs =
    {
      dns = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bun = { glob = "usr/bin/bun" } | OutputBin,
    bunx = { glob = "usr/bin/bunx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      env_state_wiring = {
        env_var = "BUN_INSTALL_CACHE_DIR",
        prefix = "bun-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "oven-sh",
        repo = "bun",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/bun --version",

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "bun --eval 'console.log(1+1)' | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
