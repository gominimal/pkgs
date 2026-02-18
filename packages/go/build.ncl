let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let variants = {
  "1.25.5" = {
    binaries_url = "https://go.dev/dl/go1.25.5.linux-amd64.tar.gz",
    binaries_sha256 = "9e9b755d63b36acf30c12a9a3fc379243714c1c6d3dd72861da637f336ebb35b",

    source_url = "https://go.dev/dl/go1.25.5.src.tar.gz",
    source_sha256 = "22a5fd0a91efcd28a1b0537106b9959b2804b61f59c3758b51e8e5429c1a954f",
  },
}
in
let version = "1.25.5" in
{
  name = "go",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = variants."%{version}".binaries_url,
      sha256 = variants."%{version}".binaries_sha256,
    } | Source,
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
    } | Attrs,
} | BuildSpec
