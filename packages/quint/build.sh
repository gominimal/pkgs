#!/bin/sh
set -eu

# Quint CLI from npm (`@informalsystems/quint`), plus the Rust evaluator it would
# otherwise DOWNLOAD at run time.
#
# Two halves:
#   1. `npm ci` from the committed package-lock.json into a package-PRIVATE
#      libexec prefix (never the shared usr/lib/node_modules the node runtime
#      owns; AGENTS.md "Node pattern").
#   2. `quint run` / `quint test` / `quint repl` default to `--backend rust`,
#      whose binary (`quint_evaluator`) upstream fetches on first use from the
#      GitHub release `evaluator/<QUINT_EVALUATOR_VERSION>` into
#      $QUINT_HOME (~/.quint) — an unpinned, unhashed prebuilt download at run
#      time. We build that evaluator from source here instead and patch the
#      lookup to return it, so nothing is ever fetched.

V="${MINIMAL_ARG_VERSION:?build.ncl forwards version}"
EV="${MINIMAL_ARG_EVALUATOR_VERSION:?build.ncl forwards evaluator_version}"

# --- 1. the npm CLI ---------------------------------------------------------
# Guard: the committed lock must pin the build.ncl version (the updater
# regenerates it on a bump; this catches a hand-edited version drift).
grep -qF "\"@informalsystems/quint\": \"$V\"" package.json ||
  { echo "package.json does not pin @informalsystems/quint $V — regenerate the lockfile" >&2; exit 1; }

src="$(pwd)"
prefix="$OUTPUT_DIR/usr/libexec/quint"
mkdir -p "$prefix"
cp package.json package-lock.json "$prefix/"
cd "$prefix"
# --ignore-scripts: the only install script in the tree is protobufjs's
# postinstall, a version-scheme warning; quint's own `prepare` never runs for a
# registry install. Nothing here downloads a native binary.
npm ci --omit=dev --ignore-scripts --no-audit --no-fund
cd "$src"

mgr="$prefix/node_modules/@informalsystems/quint/dist/src/rust/binaryManager.js"

# The evaluator we build must be the one this quint release asks for. On a
# quint bump that moves QUINT_EVALUATOR_VERSION this fails, and the reviewer
# bumps `evaluator_version` + its Source in build.ncl.
grep -qF "exports.QUINT_EVALUATOR_VERSION = 'v$EV';" "$mgr" || {
  echo "quint $V wants a different Rust evaluator than v$EV:" >&2
  grep -F "QUINT_EVALUATOR_VERSION =" "$mgr" >&2 || true
  exit 1
}

# --- 2. the Rust evaluator, from source ---------------------------------------
tar -xzof "evaluator-v$EV.tar.gz"
cd "quint-evaluator-v$EV/evaluator"
export CC=gcc
export LD=gcc
export CARGO_INCREMENTAL=0
export RUSTFLAGS="-C linker=gcc --remap-path-prefix=$(pwd)=/builddir --remap-path-prefix=$HOME/.cargo=/cargo"
cargo build --release --locked --bin quint_evaluator
install -D -m 0755 target/release/quint_evaluator "$prefix/bin/quint_evaluator"
cd "$src"

# Point the lookup at the packaged binary. getRustEvaluatorPath() is the ONLY
# caller of the download path (fetchEvaluator); returning first makes the
# download unreachable. The path is relative to binaryManager.js
# (<prefix>/node_modules/@informalsystems/quint/dist/src/rust/), so the tree
# stays relocatable.
sig="async function getRustEvaluatorPath(version = exports.QUINT_EVALUATOR_VERSION) {"
[ "$(grep -cF "$sig" "$mgr")" = 1 ] || { echo "binaryManager.js: getRustEvaluatorPath signature moved — re-check the patch" >&2; exit 1; }
sed -i "s|^$sig\$|&\n    return path_1.default.join(__dirname, '..', '..', '..', '..', '..', '..', 'bin', 'quint_evaluator'); // minimal: packaged evaluator, never downloaded|" "$mgr"
grep -qF "// minimal: packaged evaluator, never downloaded" "$mgr" ||
  { echo "binaryManager.js: evaluator patch did not apply" >&2; exit 1; }
# Fail closed: the patched lookup must resolve to the binary we just installed.
got=$(node -e "require('$mgr').getRustEvaluatorPath().then(p => console.log(require('fs').realpathSync(p)))")
[ "$got" = "$(realpath "$prefix/bin/quint_evaluator")" ] ||
  { echo "patched getRustEvaluatorPath() resolves to '$got', not the packaged evaluator" >&2; exit 1; }

# --- 3. Apalache, from the apalache package ----------------------------------
# quint looks for <apalacheDistDir(version)>/apalache/{bin/apalache-mc,lib/apalache.jar};
# the apalache package installs /usr/lib/apalache/{bin,lib}. Only the version
# this quint pins is redirected: an explicit --apalache-version for another
# keeps upstream's download.
AV="${MINIMAL_ARG_APALACHE_VERSION:?build.ncl forwards apalache_version}"
dist="$prefix/node_modules/@informalsystems/quint/dist/src"
grep -qF "exports.DEFAULT_APALACHE_VERSION_TAG = '$AV';" "$dist/apalache.js" || {
  echo "quint $V pins a different Apalache than the packaged $AV:" >&2
  grep -F "DEFAULT_APALACHE_VERSION_TAG =" "$dist/apalache.js" >&2 || true
  exit 1
}
asig="function apalacheDistDir(version) {"
[ "$(grep -cF "$asig" "$dist/config.js")" = 1 ] || { echo "config.js: apalacheDistDir signature moved — re-check the patch" >&2; exit 1; }
sed -i "s|^$asig\$|&\n    if (version === '$AV') return '/usr/lib'; // minimal: the packaged apalache|" "$dist/config.js"
# TLC (`--backend tlc`) spawns `java` from PATH; run it on the packaged JDK,
# the one apalache's launcher is pinned to.
tsig="(0, child_process_1.spawn)('java', ["
[ "$(grep -cF "$tsig" "$dist/tlc.js")" = 1 ] || { echo "tlc.js: the java spawn moved — re-check the patch" >&2; exit 1; }
sed -i "s|(0, child_process_1.spawn)('java', \[|(0, child_process_1.spawn)('/usr/lib/jvm/bin/java', [ // minimal: the packaged jdk|" "$dist/tlc.js"
# Fail closed: the pinned version resolves to /usr/lib, another version does
# not, and no bare java spawn is left.
got=$(node -e "const c=require('$dist/config.js'); console.log(c.apalacheDistDir('$AV') + ' ' + c.apalacheDistDir('0.0.0-other'))")
case "$got" in
  "/usr/lib "*/apalache-dist-0.0.0-other) ;;
  *) echo "patched apalacheDistDir() gives '$got'" >&2; exit 1 ;;
esac
grep -qF "spawn)('/usr/lib/jvm/bin/java', [" "$dist/tlc.js" || { echo "tlc.js: java patch did not apply" >&2; exit 1; }
if grep -nF "spawn)('java'" "$dist/tlc.js"; then echo "tlc.js: a bare java spawn is left" >&2; exit 1; fi

# --- bins ---------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR/usr/bin"
ln -s ../libexec/quint/node_modules/.bin/quint "$OUTPUT_DIR/usr/bin/quint"
test -e "$OUTPUT_DIR/usr/bin/quint" || { echo "quint: npm did not install the quint bin" >&2; exit 1; }
