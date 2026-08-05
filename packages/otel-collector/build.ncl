let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.158.0" in
# OBI (OpenTelemetry eBPF Instrumentation) is compiled into otelcol-contrib as
# of 0.157.0 — the contrib manifest declares it as a component and replaces it
# with a vendored source tree at `internal/obi-src`. Upstream fetches that at
# build time (scripts/prepare-obi.sh); we pin it here instead so every input
# stays checksummed. MUST match the manifest's
# `- gomod: go.opentelemetry.io/obi <ver>` line — if a version bump changes it,
# this and the sha256 below move together, or the build fails loudly on the
# replace path rather than silently building against the wrong OBI.
let obi_version = "v0.10.0" in
{
  name = "otel-collector",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/open-telemetry/opentelemetry-collector-releases/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "5fa5c0ff17eaa4910960781347db0ccbd4878fbaae6984b5c87fcb930bc0b0f5",
      extract = true,
      strip_prefix = "opentelemetry-collector-releases-%{version}",
    } | Source,
    # Fetched un-extracted: build.sh unpacks it into `internal/obi-src` (the
    # path the manifest's `replaces:` points at). Extracting it here would merge
    # its tree into the source root and collide with the collector checkout.
    {
      url = "https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/download/%{obi_version}/obi-%{obi_version}-source-generated.tar.gz",
      sha256 = "151ef5d04bff9660743148ff20d5c833222b0b45ab15245a2968a3f7f4366dec",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    otel-collector = { glob = "usr/bin/otelcol-contrib" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "open-telemetry",
        repo = "opentelemetry-collector-releases",
      },
    } | Attrs,
} | BuildSpec
