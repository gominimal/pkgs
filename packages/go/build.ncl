let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
# THE LADDER-CLOSE (#19): amd64 bootstraps from our own hex0-rooted Go, not a go.dev bindist.
# Chain: hex0 -> ... -> gcc-15.2.0-glibc -> go-1.4 (C only) -> 1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9.
# arm64's slot is the SEALED gccgo-rooted go1.24.9 from the arm ladder (the BEDROCK ROOT
# Source below — #631 flipped it): Go 1.5 was the first release with an arm64 port, so the
# C-hosted root cannot produce an arm64 toolchain directly; gccgo is the arm root instead.
let go-1-24-9 = import "../go-1.24.9/build.ncl" in
let git = import "../git/build.ncl" in

let version = "1.27.0" in
let variants = {
  # NOTE for the version updater: bumping go here means updating `version` and
  # `source_sha256` ONLY.  There is no bindist to update — BOTH arches bootstrap from
  # hex0-rooted pins (amd64: the go-1.24.9 rung build_dep; arm64: the sealed gs:// slot),
  # and those change only when go's minBootstrap moves past 1.24 (src/cmd/dist/buildtool.go;
  # 1.27.0 pins go1.24.6, so the 1.24.9 root stays valid).
  source_url = "https://go.dev/dl/go%{version}.src.tar.gz",
  source_sha256 = "7002403d7cc44529ef6d26f69a44818263395ead7c16c05a5808ae047ebeb0e5",
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
  # WHY needs SURVIVES the offline flip: the CS builder has no egress and the attested
  # builds above ran fully offline; `needs` is retained for (a) the arm64 stage0 download
  # path (rust, until the arm rungs land) and (b) non-CS environments that build this
  # recipe without pre-staged mirrors.  Dropping it is a follow-up once arm closes.
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
