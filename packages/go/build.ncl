let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let variants = {
  "1.25.8" = {
    amd64_url = "https://go.dev/dl/go1.25.8.linux-amd64.tar.gz",
    amd64_sha256 = "ceb5e041bbc3893846bd1614d76cb4681c91dadee579426cf21a63f2d7e03be6",

    arm64_url = "https://go.dev/dl/go1.25.8.linux-arm64.tar.gz",
    arm64_sha256 = "7d137f59f66bb93f40a6b2b11e713adc2a9d0c8d9ae581718e3fad19e5295dc7",

    source_url = "https://go.dev/dl/go1.25.8.src.tar.gz",
    source_sha256 = "e988d4a2446ac7fe3f6daa089a58e9936a52a381355adec1c8983230a8d6c59e",
  },
}
in
let version = "1.25.8" in
{
  name = "go",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = variants."%{version}".amd64_url,
          sha256 = variants."%{version}".amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = variants."%{version}".arm64_url,
          sha256 = variants."%{version}".arm64_sha256,
        } | Source,
    } target,
    {
      url = variants."%{version}".source_url,
      sha256 = variants."%{version}".source_sha256,
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
