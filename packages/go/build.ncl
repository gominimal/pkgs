let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.26.6" in
let variants = {
  amd64_url = "https://go.dev/dl/go%{version}.linux-amd64.tar.gz",
  amd64_sha256 = "708effb774be8237570d0add163225abbdfaf4fca28b2611df167beba4feef89",

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
          # BEDROCK ROOT (arm64): this bootstrap Go is go1.24.9 from the hex0-rooted arm
          # ladder (hex0 -> gccgo-15.2.0 -> go1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9; gccgo is
          # the Go frontend shipped inside the gcc source tarball, so no new trust root),
          # replacing the go.dev linux-arm64 bindist. The three upper rungs reproduced
          # byte-identically across two runs, and 1.17.13 reproduced under two independently
          # built gccgo hosts. Seal transcripts and evidence: gominimal/minimermetic#16.
          # `extract = true` unpacks it to ./go — build.sh MUST move it aside before untarring
          # the go source tree into that same path.
          url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/fb0df54229ff3bf08ecde83e6095b07fbdb7d0b77c586ed4d468b7f546a8be56/go1.24.9-aarch64.tar.zst",
          sha256 = "fb0df54229ff3bf08ecde83e6095b07fbdb7d0b77c586ed4d468b7f546a8be56",
          extract = true,
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
