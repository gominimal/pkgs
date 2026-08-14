let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
# THE LADDER-CLOSE (#19): BOTH arches now bootstrap from our own hex0-rooted Go, not a go.dev
# bindist.  amd64: hex0 -> ... -> gcc-15.2.0-glibc -> go-1.4 (C only) -> 1.17.13 -> 1.20.14
# -> 1.22.6 -> 1.24.9 (the rung package below).  arm64 has NO go-1.4 route (Go 1.5 was the first
# arm64 port) — its ladder roots in gccgo instead: hex0 -> ... -> gcc-15.2.0 (gccgo is the C++
# frontend inside the gcc tarball we already mirror, so no new trust root) -> go-1.17.13
# -> 1.20.14 -> 1.22.6 -> 1.24.9, delivered as a mirrored sealed tarball because the pkgs stage0
# ladder is amd64-seeded and cannot host the arm rungs (bedrock-aarch64/ built them).
let go-1-24-9 = import "../go-1.24.9/build.ncl" in

let version = "1.26.5" in
let variants = {
  amd64_url = "https://go.dev/dl/go%{version}.linux-amd64.tar.gz",
  amd64_sha256 = "5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053",

  source_url = "https://go.dev/dl/go%{version}.src.tar.gz",
  source_sha256 = "495be4bc87176ac567392e5b4116abd98466d33d7b49d41e764ccc6976b2dc42",
}
in
{
  name = "go",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } => go-1-24-9,
      { arch = 'Arm64, .. } =>
        {
          # BEDROCK ROOT (aarch64): go1.24.9 from the hex0-rooted arm ladder
          # (hex0 -> gccgo-15.2.0 -> go1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9), replacing the
          # go.dev linux-arm64 bindist.  GOLAD_ALL_PASS + GOSEAL_ALL_IDENTICAL: 1.20.14/1.22.6/
          # 1.24.9 are 2-run byte-sealed (inner bin/go 8c4f9902..., same-machine seal), and
          # 1.17.13 reproduced byte-identically under two DIFFERENT gccgo builds; gccgo itself is
          # gate-passed twice, not byte-sealed (driver-only variance, proven non-propagating).
          # `extract = true` unpacks it to ./go — build.sh MUST move it aside before untarring
          # the go source tree into that same path.
          url = "gs://minimalmertic-hermetic-mirror/sha256/fb0df54229ff3bf08ecde83e6095b07fbdb7d0b77c586ed4d468b7f546a8be56/go1.24.9-aarch64.tar.zst",
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
