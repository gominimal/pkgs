# Quint, the specification language for distributed protocols (the npm
# `@informalsystems/quint` CLI), with its Rust simulator built from source.
#
# `quint run` / `test` / `repl` default to `--backend rust`, and upstream
# downloads that backend (`quint_evaluator`) from a GitHub release into ~/.quint
# on first use. build.sh builds it from the pinned evaluator source below and
# patches the lookup to the packaged copy, so no run of quint fetches a binary.
#
# NOT packaged: Apalache (`quint verify`, also the jar `--backend tlc` uses).
# `quint verify` still downloads apalache.tgz (a JVM distribution, unhashed)
# from GitHub into ~/.quint on first use and then needs `java` on PATH; in a
# session without network or a JDK it fails with an error and verifies nothing.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.33.1" in
# The Rust evaluator release this quint version pins (QUINT_EVALUATOR_VERSION in
# dist/src/rust/binaryManager.js). build.sh fails if the two disagree, so a quint
# bump that moves it stops for a reviewer to bump this and the Source below.
let evaluator_version = "0.7.1" in
{
  name = "quint",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "package.json" } | Local,
    { file = "package-lock.json" } | Local,
    {
      # Upstream: https://github.com/quint-co/quint/archive/refs/tags/evaluator/v0.7.1.tar.gz
      url = "gs://minimal-staging-archives/quint-co/quint/evaluator-v%{evaluator_version}.tar.gz",
      sha256 = "5d4cd64a69f5d8b61ed800ed14044899930029c7c14f160d0aedc212a1bf5432",
      # a GitHub archive under a renamed file; build.sh unpacks it
      extract = false,
    } | Source,
    base,
    node-lts,
    rust,
    toolchain,
  ],
  runtime_deps = [
    coreutils, # `#!/usr/bin/env node`
    subsetOf node-lts ["node"],
    # quint_evaluator (Rust)
    glibc,
    subsetOf gcc ["libgcc"],
  ],
  # npm ci fetches the locked tree; cargo fetches the evaluator's locked crates.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  build_args = {
    include version,
    include evaluator_version,
  },
  outputs = {
    quint = { glob = "usr/bin/quint" } | OutputBin,
    libexec = { glob = "usr/libexec/quint/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "quint-co",
        repo = "quint",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/quint --version | grep -qx '%{version}'"],
        ],
      } | Test,
    # typecheck + the simulator on both backends, with HOME and QUINT_HOME
    # pointed at empty directories: the Rust backend must use the packaged
    # evaluator and leave QUINT_HOME empty (upstream would download into it).
    # A violated invariant must fail, so a simulator that checks nothing can't
    # pass.
    simulate =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              mkdir -p home qhome
              export HOME="$PWD/home" QUINT_HOME="$PWD/qhome"
              cat > counter.qnt <<'EOF'
              module counter {
                var x: int
                action init = x' = 0
                action step = x' = x + 1
                val nonNegative = x >= 0
                val belowThree = x < 3
              }
              EOF
              quint typecheck counter.qnt
              for b in rust typescript; do
                quint run --backend "$b" --max-samples 50 --max-steps 10 --invariant nonNegative counter.qnt > ok.log 2>&1 || { cat ok.log; exit 1; }
                grep -q 'No violation found' ok.log || { cat ok.log; exit 1; }
                if quint run --backend "$b" --max-samples 50 --max-steps 10 --invariant belowThree counter.qnt > bad.log 2>&1; then
                  cat bad.log; echo "backend $b: violated invariant passed" >&2; exit 1
                fi
                grep -qi 'violation' bad.log || { cat bad.log; exit 1; }
              done
              if grep -qi 'fetching rust evaluator' ok.log bad.log; then echo "quint tried to download its evaluator" >&2; exit 1; fi
              [ -z "$(ls -A qhome)" ] || { ls -laR qhome; echo "quint wrote to QUINT_HOME" >&2; exit 1; }
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
