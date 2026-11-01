let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.164.0" in
# OBI (OpenTelemetry eBPF Instrumentation) is compiled into otelcol-contrib as
# of 0.157.0 — the contrib manifest declares it as a component and replaces it
# with a vendored source tree at `internal/obi-src`. Upstream fetches that at
# build time (scripts/prepare-obi.sh); we pin it here instead so every input
# stays checksummed. MUST match the manifest's
# `- gomod: go.opentelemetry.io/obi/collector <ver>` line (the line upstream's
# prepare-obi.sh reads; before 0.163 it was `go.opentelemetry.io/obi <ver>`).
# It does NOT follow the package version — on a bump, this and the sha256 below
# move together; build.sh fails loudly if they disagree with the manifest.
let obi_version = "v0.15.2" in
{
  name = "otel-collector",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/open-telemetry/opentelemetry-collector-releases/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "15c971e28e30dcb54c832df92ae0df918fd19161e526b0022b17da7ac5d6c6fb",
      extract = true,
      strip_prefix = "opentelemetry-collector-releases-%{version}",
    } | Source,
    # Fetched un-extracted: build.sh unpacks it into `internal/obi-src` (the
    # path the manifest's `replaces:` points at). Extracting it here would merge
    # its tree into the source root and collide with the collector checkout.
    {
      url = "https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/download/%{obi_version}/obi-%{obi_version}-source-generated.tar.gz",
      sha256 = "d3cbec602e3ab7b357d2f4a57b29e502365f9098808418e8b4d96dec8fa9281f",
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
