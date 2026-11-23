let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let detbuild = import "../detbuild/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let python = import "../python/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let ca-certificates = import "../ca-certificates/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.17.0" in
{
  name = "oha",
  # HTTP load generator (constant-rate `-q`, latency histograms, JSON/CSV output),
  # built from source with upstream's default features (rustls, no native-tls, no
  # http3). The binary statically links three C libraries that cargo builds from the
  # crates: aws-lc (rustls' crypto provider, via aws-lc-sys, built with cmake), jemalloc
  # (tikv-jemalloc-sys, autotools + make) and SQLite (rusqlite "bundled", for
  # `--output-format` db exports).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/hatoo/oha/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cd869a518c11252b4aaf2c12dc0c64527df2b69bc8f55b104139814912e67817",
      extract = true,
      strip_prefix = "oha-%{version}",
    } | Source,
    # RUSTSEC-2026-0592 (url < 2.5.9, stack overflow in Url::origin() on nested blob:
    # URLs): moves upstream's Cargo.lock to url 2.5.9 and form_urlencoded 1.2.3, which
    # it requires. Lock-only, produced by `cargo update -p url@2.5.8 --precise 2.5.9`.
    # oha does not call Url::origin itself; this keeps the shipped crate set free of
    # known advisories. Drop on the first upstream release that locks url >= 2.5.9 (the
    # stale patch then fails at `patch`).
    { file = "rustsec-2026-0592-url-lock.patch" } | Local,
    base,
    rust,
    toolchain,
    cmake,
    make,
    patch,
    # Deterministic getrandom/getentropy for the offline build (see build.sh).
    detbuild,
  ],

  # rustls-native-certs reads the system store (/etc/ssl/certs) for https:// targets;
  # oha carries no roots of its own (no webpki-roots).
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    ca-certificates,
  ],

  # cargo fetch (see build.sh)
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    oha = { glob = "usr/bin/oha" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [["/bin/bash", "-c", "oha --version | grep -qx 'oha %{version}'"]],
      } | Test,
    # A real load run over loopback: a Python http.server serves a file, oha sends 50
    # requests at a fixed 100 QPS over 2 connections without the TUI, and the JSON summary
    # must report every one of them as a 200 and a success rate of 1.
    loopback_load =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, python],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              mkdir www
              printf 'hello from oha test\n' > www/index.html
              python3 -m http.server 38917 --bind 127.0.0.1 --directory www >server.log 2>&1 &
              srv=$!
              trap 'kill $srv 2>/dev/null || true' EXIT
              for _ in $(seq 50); do
                python3 -c 'import socket; socket.create_connection(("127.0.0.1", 38917), 1).close()' 2>/dev/null && break
                sleep 0.1
              done
              oha -n 50 -c 2 -q 100 --no-tui --output-format json http://127.0.0.1:38917/index.html > out.json
              cat out.json
              python3 - <<'PYEOF'
              import json, sys
              r = json.load(open("out.json"))
              codes = r["statusCodeDistribution"]
              rate = r["summary"]["successRate"]
              print("successRate=%s codes=%s" % (rate, codes))
              sys.exit(0 if rate == 1 and codes == {"200": 50} else 1)
              PYEOF
            "%
          ],
        ],
      } | Test,
    # A closed port is an error, not a success: every request fails with a connection
    # error and the summary says so.
    closed_port =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, python],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              oha -n 5 -c 1 --no-tui --output-format json http://127.0.0.1:1/ > out.json || true
              cat out.json >&2
              python3 - <<'PYEOF'
              import json, sys
              r = json.load(open("out.json"))
              errs = r.get("errorDistribution")
              print(r["summary"]["successRate"], errs, file=sys.stderr)
              sys.exit(0 if r["summary"]["successRate"] == 0 and errs else 1)
              PYEOF
            "%
          ],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "hatoo",
        repo = "oha",
      },
    } | Attrs,
} | BuildSpec
