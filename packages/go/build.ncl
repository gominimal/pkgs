let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let git = import "../git/build.ncl" in

let version = "1.26.6" in
let variants = {
  amd64_url = "https://go.dev/dl/go%{version}.linux-amd64.tar.gz",
  amd64_sha256 = "708effb774be8237570d0add163225abbdfaf4fca28b2611df167beba4feef89",

  arm64_url = "https://go.dev/dl/go%{version}.linux-arm64.tar.gz",
  arm64_sha256 = "d0507e9e9d7fe012aae570108cbd76c15de879e17130ab8cb90d4d7445cb1f2e",

  source_url = "https://go.dev/dl/go%{version}.src.tar.gz",
  source_sha256 = "a0721c54c688901448d77ad9b3ec7ea7c474730755ff891382e92ecb93ff2cb1",
}
in
{
  name = "go",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = variants.amd64_url,
          sha256 = variants.amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = variants.arm64_url,
          sha256 = variants.arm64_sha256,
        } | Source,
    } target,
    {
      url = variants.source_url,
      sha256 = variants.source_sha256,
    } | Source,
    base,
    toolchain,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  # git rides along wherever the Go toolchain goes: GOPROXY's `|direct`
  # fallback (go.env above) fetches modules via VCS, and a sandbox without
  # git turns the fallback into "exec: git: executable file not found"
  # (observed pkgs#648: the fallback fired on a proxy reset and died here).
  runtime_deps = [git],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    go_bin = { glob = "usr/bin/go" } | OutputBin,
    gofmt_bin = { glob = "usr/bin/gofmt" } | OutputBin,

    goroot_api_data = { glob = "usr/go/api/*" } | OutputData,
    goroot_bins = { glob = "usr/go/bin/*" } | OutputBin,
    goroot_lib_fips = { glob = "usr/go/lib/fips140/**" } | OutputData,
    goroot_lib_time = { glob = "usr/go/lib/time/**" } | OutputData,
    goroot_lib_wasm = { glob = "usr/go/lib/wasm/**" } | OutputData,
    goroot_misc = { glob = "usr/go/misc/**" } | OutputData,
    goroot_pkg_bins = { glob = "usr/go/pkg/tool/*/**" } | OutputBin,
    goroot_src = { glob = "usr/go/src/**", allow_executable = true } | OutputData,
    goroot_test = { glob = "usr/go/test/**" } | OutputData,

    goroot_goenv = { glob = "usr/go/go.env" } | OutputData,
    goroot_license = { glob = "usr/go/LICENSE" } | OutputData,
    goroot_patents = { glob = "usr/go/PATENTS" } | OutputData,
    goroot_version = { glob = "usr/go/VERSION" } | OutputData,

    includes = { glob = "usr/go/pkg/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      repology_project = "go",

      # When Go is used in a task environment, a `gocache` directory is created
      # in a persistent state directory, the path of which is set as GOCACHE.
      #
      # This ultimately allows Go to store intermediate build artifacts across
      # task environments which share the same state, speeding up builds.
      env_state_wiring = [
        {
          env_var = "GOCACHE",
          prefix = "gocache",
        },
        {
          env_var = "GOMODCACHE",
          prefix = "gomodcache",
        },
      ],
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "go",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
