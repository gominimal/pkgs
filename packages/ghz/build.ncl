let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let go = import "../go/build.ncl" in
let grep = import "../grep/build.ncl" in
let otel-collector = import "../otel-collector/build.ncl" in

# ghz: a gRPC load generator (unary and streaming calls; proto, protoset or
# server reflection). Only the `ghz` CLI is shipped; upstream's `ghz-web`
# dashboard (cgo + sqlite) is not. Static, as upstream releases it.
let version = "0.121.0" in
{
  name = "ghz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/bojand/ghz/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "d92ed00a2cd1be3b14fe680e1615e9dace4fd4cf6d679811173ae7f2611ad762",
      extract = true,
    } | Source,
    base,
    go,
  ],
  runtime_deps = [],
  # Go module downloads (verified against go.sum).
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    ghz = { glob = "usr/bin/ghz" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "ghz",
      source_provenance = {
        category = 'GithubRepo,
        owner = "bojand",
        repo = "ghz",
      },
    } | Attrs,

  tests = {
    # A real gRPC server in the box: the OpenTelemetry collector's OTLP/gRPC
    # receiver. ghz sends 50 unary TraceService/Export calls, each carrying
    # one span, from a .proto that declares just the OTLP fields it sets
    # (same package, service and field numbers, so the wire format matches).
    # Every call must come back OK, and the collector's debug exporter must
    # have received all 50 spans. Then a call to a closed port must be
    # reported as refused.
    # The sandbox has no /etc/hosts, so every address is 127.0.0.1.
    otlp_load =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep, otel-collector],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              ghz --version 2>&1 | grep -qxF "%{version}"
              ghz --help 2>&1 | grep -q -- '--proto'
              d=$(mktemp -d)
              cat >"$d/otelcol.yaml" <<'YAML'
              receivers:
                otlp:
                  protocols:
                    grpc:
                      endpoint: 127.0.0.1:43170
              exporters:
                debug:
                  verbosity: detailed
              service:
                telemetry:
                  metrics:
                    level: none
                  # The collector's log (which the debug exporter writes to)
                  # is sampled by default; the test counts every span.
                  logs:
                    sampling:
                      enabled: false
                pipelines:
                  traces:
                    receivers: [otlp]
                    exporters: [debug]
              YAML
              cat >"$d/trace.proto" <<'PROTO'
              syntax = "proto3";
              package opentelemetry.proto.collector.trace.v1;
              service TraceService {
                rpc Export(ExportTraceServiceRequest) returns (ExportTraceServiceResponse) {}
              }
              message ExportTraceServiceRequest { repeated ResourceSpans resource_spans = 1; }
              message ExportTraceServiceResponse {}
              message ResourceSpans { repeated ScopeSpans scope_spans = 2; }
              message ScopeSpans { repeated Span spans = 2; }
              message Span {
                bytes trace_id = 1;
                bytes span_id = 2;
                string name = 5;
              }
              PROTO
              otelcol-contrib --config "file:$d/otelcol.yaml" >"$d/otelcol.log" 2>&1 &
              opid=$!
              trap 'kill $opid 2>/dev/null || true; tail -n 40 "$d/otelcol.log"' EXIT
              for i in $(seq 100); do (exec 3<>/dev/tcp/127.0.0.1/43170) 2>/dev/null && break; sleep 0.2; done
              span='{"resource_spans":[{"scope_spans":[{"spans":[{"trace_id":"AAAAAAAAAAAAAAAAAAAAAQ==","span_id":"AAAAAAAAAAE=","name":"ghz-smoke"}]}]}]}'
              ghz --insecure --proto "$d/trace.proto" \
                --call opentelemetry.proto.collector.trace.v1.TraceService.Export \
                -d "$span" -n 50 -c 5 --format json 127.0.0.1:43170 >"$d/report.json"
              cat "$d/report.json"; echo
              grep -qF '"statusCodeDistribution":{"OK":50}' "$d/report.json"
              for i in $(seq 50); do [ "$(grep -c 'Name *: ghz-smoke' "$d/otelcol.log")" = 50 ] && break; sleep 0.2; done
              echo "spans received: $(grep -c 'Name *: ghz-smoke' "$d/otelcol.log")"
              [ "$(grep -c 'Name *: ghz-smoke' "$d/otelcol.log")" = 50 ]
              # Nothing listens on 127.0.0.1:1. ghz still exits 0 there (it
              # reports failed calls rather than failing itself), so the
              # report must count the one call as Unavailable, refused.
              ghz --insecure --proto "$d/trace.proto" \
                --call opentelemetry.proto.collector.trace.v1.TraceService.Export \
                -d "$span" -n 1 --connect-timeout 2s --format json 127.0.0.1:1 >"$d/closed.json" || true
              cat "$d/closed.json"; echo
              grep -qF '"statusCodeDistribution":{"Unavailable":1}' "$d/closed.json"
              grep -qF 'connection refused' "$d/closed.json"
              echo PASS
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
