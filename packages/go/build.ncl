let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.26.2" in
let variants = {
  amd64_url = "https://go.dev/dl/go%{version}.linux-amd64.tar.gz",
  amd64_sha256 = "990e6b4bbba816dc3ee129eaeaf4b42f17c2800b88a2166c265ac1a200262282",

  arm64_url = "https://go.dev/dl/go%{version}.linux-arm64.tar.gz",
  arm64_sha256 = "c958a1fe1b361391db163a485e21f5f228142d6f8b584f6bef89b26f66dc5b23",

  source_url = "https://go.dev/dl/go%{version}.src.tar.gz",
  source_sha256 = "2e91ebb6947a96e9436fb2b3926a8802efe63a6d375dffec4f82aa9dbd6fd43b",
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
