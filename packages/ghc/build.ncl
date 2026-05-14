let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let perl = import "../perl/build.ncl" in
let python = import "../python/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let xz = import "../xz/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "9.10.1" in
{
  name = "ghc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-src.tar.xz",
      sha256 = "bf386a302d4ee054791ffd51748900f15d71760fd199157922d120cc1f89e2f7",
      extract = false,
    } | Source,
    base,
    toolchain,
    perl,
    python,
    gmp,
    xz,
    tar,
  ],
  runtime_deps = [
    gmp,
  ],

  cmd = "./build.sh",

  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libghc = { glob = "usr/lib/ghc/**" } | OutputData,
    libs = { glob = "usr/lib/**/*.so*" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    docs = { glob = "usr/share/doc/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "ghc",
        repo = "ghc",
      },
      build_cost_multiple = 6,
    } | Attrs,

  replace_on_cycle =
    {
      name = "ghc (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-x86_64-deb12-linux.tar.xz",
              sha256 = "330c43eea88434e2de3480e05a5ea5cf7664090ef12245602dfe8463ac5dc496",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "https://downloads.haskell.org/~ghc/%{version}/ghc-%{version}-aarch64-deb11-linux.tar.xz",
              sha256 = "1db449c445d34779d4deaba22341576f7b512a05b6c2b5cb64f3846d1509714e",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        gmp,
      ],
      outputs = {
        bins = { glob = "usr/bin/*" } | OutputBin,
        libghc = { glob = "usr/lib/ghc/**" } | OutputData,
        libs = { glob = "usr/lib/**/*.so*" } | OutputLib,
        mans = { glob = "usr/share/man/**" } | OutputData,
        docs = { glob = "usr/share/doc/**" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
