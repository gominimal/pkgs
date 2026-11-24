#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ARCH="x64" ;;
  aarch64) ARCH="arm64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

DOTNET_VERSION="${MINIMAL_ARG_DOTNET_VERSION}"

mkdir runner
tar -xof "actions-runner-linux-${ARCH}-${MINIMAL_ARG_VERSION}.tar.gz" -C runner
mkdir dotnet
tar -xof "dotnet-runtime-${DOTNET_VERSION}-linux-${ARCH}.tar.gz" -C dotnet

# --- Swap the bundled .NET 8 runtime for .NET 10 -----------------------------
#
# Upstream publishes the runner self-contained on .NET 8 (out of support since
# 2026-11-10; actions/runner#4757 moves it to .NET 10 but is not released).
# .NET 8's crypto shim only dlopens libssl.so.3 and older, so it needed
# openssl-3.5. .NET 10.0.15 also loads OpenSSL 4's libssl.so.4
# (dotnet/runtime#135534), so the runner's own assemblies (compiled for net8.0)
# run here on Microsoft's .NET 10 shared framework instead, still self-contained
# in bin/: the runtime-pack files the app's deps.json lists are replaced by the
# .NET 10 framework's, and the apps' deps.json are removed so the host puts
# every assembly in bin/ on the TPA (hostpolicy's documented no-deps.json mode).
# Upstream's own .NET 10 PR needed no source change: only the TargetFramework
# and redundant PackageReferences moved.
bin=runner/bin
fw="dotnet/shared/Microsoft.NETCore.App/${DOTNET_VERSION}"
fxr="dotnet/host/fxr/${DOTNET_VERSION}/libhostfxr.so"
test -d "$fw"
test -f "$fxr"
test -f "$fw/libSystem.Security.Cryptography.Native.OpenSsl.so"

apps="Runner.Listener Runner.Worker Runner.PluginHost"

# Fail closed unless the runner still bundles a .NET 8 runtime pack: once
# upstream ships .NET 10 this whole block should go, not silently re-run.
packs=$(for app in $apps; do
  jq -r '.targets[] | keys[] | select(startswith("runtimepack.Microsoft.NETCore.App.Runtime."))' "$bin/$app.deps.json"
done | sort -u)
test "$(printf '%s\n' "$packs" | wc -l)" -eq 1
case "$packs" in
  */8.0.*) ;;
  *) echo "expected one .NET 8 runtime pack in the runner's deps.json, found: $packs" >&2; exit 1 ;;
esac

# Every file of the old runtime pack. Each must have a .NET 10 counterpart
# (libhostfxr.so comes from host/fxr), so nothing of .NET 8 is left behind.
for app in $apps; do
  jq -r '.targets[] | to_entries[] | select(.key | startswith("runtimepack.")) | .value | ((.runtime // {}) | keys[]), ((.native // {}) | keys[])' "$bin/$app.deps.json"
done | sort -u > old-runtime.txt
test -s old-runtime.txt
while read -r f; do
  case "$f" in */*|"") echo "unexpected runtime-pack path: '$f'" >&2; exit 1 ;; esac
  test "$f" = libhostfxr.so || test -e "$fw/$f" || { echo ".NET 8 runtime file $f has no .NET ${DOTNET_VERSION} counterpart" >&2; exit 1; }
  rm "$bin/$f"
done < old-runtime.txt

# NuGet-provided assemblies the .NET 10 framework also carries (System.Text.Json
# and friends): keep whichever is newer, as the host would for a
# framework-dependent app (assembly version, then file version).
jq -r '.targets[] | to_entries[] | .value.runtime // {} | to_entries[] | "\(.key)\t\(.value.assemblyVersion)\t\(.value.fileVersion)"' \
  "$fw/Microsoft.NETCore.App.deps.json" > fw-versions.tsv
for app in $apps; do
  jq -r '.targets[] | to_entries[] | select(.key | startswith("runtimepack.") | not) | .value.runtime // {} | to_entries[] | select(.key | test("^lib/[^/]+/[^/]+\\.dll$")) | "\(.key | split("/") | last)\t\(.value.assemblyVersion)\t\(.value.fileVersion)"' "$bin/$app.deps.json"
done | sort -u > app-versions.tsv
newer() { # newer A B: is version A strictly newer than B
  test "$1" != "$2" && test "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1"
}
for f in $(ls "$fw"); do
  case "$f" in Microsoft.NETCore.App.deps.json|Microsoft.NETCore.App.runtimeconfig.json) continue ;; esac
  if [ -e "$bin/$f" ]; then
    fwv=$(awk -F'\t' -v f="$f" '$1 == f { print $2 "." $3 }' fw-versions.tsv)
    appv=$(awk -F'\t' -v f="$f" '$1 == f { print $2 "." $3 }' app-versions.tsv | sort -V | tail -1)
    test -n "$fwv" && test -n "$appv" || { echo "$f is in both the runner and .NET ${DOTNET_VERSION} without a version to compare" >&2; exit 1; }
    if newer "$appv" "$fwv"; then
      echo "keeping the runner's $f ($appv over framework $fwv)"
      continue
    fi
  fi
  cp -p "$fw/$f" "$bin/$f"
done
cp -p "$fxr" "$bin/libhostfxr.so"

for app in $apps; do
  rm "$bin/$app.deps.json"
  jq --arg v "$DOTNET_VERSION" '.runtimeOptions.includedFrameworks |= map(if .name == "Microsoft.NETCore.App" then .version = $v else . end)' \
    "$bin/$app.runtimeconfig.json" > rc.json
  grep -q "\"$DOTNET_VERSION\"" rc.json
  mv rc.json "$bin/$app.runtimeconfig.json"
done

# Fail closed: no ELF in the runner may NEED libssl.so.3 / libcrypto.so.3, and
# the crypto shim must be the one that knows libssl.so.4. (.NET dlopens libssl,
# so the NEEDED check alone would pass .NET 8 too; the shim check is the one
# that catches a .NET 8 shim.)
# A file readelf cannot read fails the build: it is not a pass.
find runner -type f | while read -r f; do
  if [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" = 7f454c46 ]; then
    dyn=$(readelf -d "$f") || { echo "readelf could not read $f" >&2; exit 1; }
    if printf '%s\n' "$dyn" | grep -E 'NEEDED.*\[lib(ssl|crypto)\.so\.3\]'; then
      echo "$f still NEEDs OpenSSL 3" >&2; exit 1
    fi
  fi
done
grep -c 'libssl\.so\.4' "$bin/libSystem.Security.Cryptography.Native.OpenSsl.so"
cmp "$bin/libSystem.Security.Cryptography.Native.OpenSsl.so" "$fw/libSystem.Security.Cryptography.Native.OpenSsl.so"
cmp "$bin/libcoreclr.so" "$fw/libcoreclr.so"
cmp "$bin/System.Private.CoreLib.dll" "$fw/System.Private.CoreLib.dll"

mkdir -p $OUTPUT_DIR/usr/{bin,lib}
mv runner $OUTPUT_DIR/usr/lib/actions-runner

# What the wrappers compare to decide whether a RUNNER_HOME holds this package's
# runner: the versions plus a hash over every file the package ships.
tree=$(cd "$OUTPUT_DIR/usr/lib/actions-runner" && {
  find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
  find . -type l -printf 'link %p %l\n' | LC_ALL=C sort
} | sha256sum | cut -d' ' -f1)
test -n "$tree"
printf 'actions-runner %s dotnet %s tree %s\n' "$MINIMAL_ARG_VERSION" "$DOTNET_VERSION" "$tree" \
  > "$OUTPUT_DIR/usr/lib/actions-runner/.minimal-package-stamp"


# Shared by both wrappers.
#
# RUNNER_HOME is a state directory that outlives package upgrades, and the
# runner runs from its copy there. A home set up by an older package (the .NET 8
# runner before this one) would keep that bin/ for good, and with no
# libssl.so.3 in the closure that runner cannot make a TLS connection. So a
# home is current only when its installed stamp equals the package's and no
# upstream self-update has rearranged it (update.sh moves bin/ to bin.<version>
# and makes bin a symlink to the new release). Otherwise bin/, externals/ and
# the top-level scripts are replaced from the package, and self-update
# leftovers (bin.*, externals.*) are dropped. The registration (.runner*,
# .credentials*), .env, .path, _work and _diag are not in the package and are
# left alone.
#
# The wrapper deletes only in a directory that holds a runner
# (bin/Runner.Listener) or one it was copying into when a start was
# interrupted (.minimal-copying). Any other directory with a bin/ or externals/
# is refused, so RUNNER_HOME=$HOME does not cost ~/bin. While a runner from the
# home is running it refuses too. One start at a time sets a home up (a lock
# holding the starting PID; a lock whose process is gone is taken over), and
# the stamp is checked again under the lock. The installed stamp is written
# only after every step succeeded, so a copy that failed (a full disk) is redone
# by the next start.
cat > prelude.sh << 'EOF'
pkg=/usr/lib/actions-runner
home_current() {
    local bin_dirs=("$RUNNER_HOME"/bin.*)
    # (no cmp: diffutils is not in the runtime closure)
    [ -f "$RUNNER_HOME/.minimal-installed-stamp" ] &&
        [ "$(cat "$pkg/.minimal-package-stamp")" = "$(cat "$RUNNER_HOME/.minimal-installed-stamp")" ] &&
        [ -d "$RUNNER_HOME/bin" ] && [ ! -L "$RUNNER_HOME/bin" ] && [ ! -e "${bin_dirs[0]}" ]
}
lock_home() { # lock_home <home>
    lock=$1/.minimal-setup.lock
    local owner err waited=0 probe=$1/.minimal-write-test.$$
    # The lock is created in the home, so a home this start cannot write to is
    # refused here instead of waited on.
    if ! { : > "$probe" && rm -f "$probe"; }; then
        echo "Could not write to $RUNNER_HOME (the error is above). Fix the permissions there, or free space if the disk is full, then start again." >&2
        exit 1
    fi
    # -T: a directory at $lock is a conflict, not a place to create the link in.
    until err=$(ln -sT "$$" "$lock" 2>&1); do
        if owner=$(readlink "$lock" 2>/dev/null); then
            if [ ! -d "/proc/$owner" ]; then
                # Its process is gone. Starts that found the same dead PID take
                # the lock over one at a time: each must first create
                # $lock.takeover-<PID>, and the one that did removes the lock only
                # if it still names that PID. Only a start's own exit removes a
                # lock that names a live start, so two starts never both hold it.
                if ln -sT "$$" "$lock.takeover-$owner" 2>/dev/null; then
                    if [ "$(readlink "$lock" 2>/dev/null)" = "$owner" ]; then
                        rm -f "$lock"
                    fi
                    rm -f "$lock.takeover-$owner"
                    continue
                fi
            fi
        elif [ -e "$lock" ]; then
            echo "$lock is not a lock an actions-runner start made (that is a symlink to the PID of the start), so this start stopped. Remove it, then start again." >&2
            exit 1
        fi
        # Every other failure waits, and counts against the limit.
        if [ "$waited" -ge 600 ]; then
            if [ -n "$owner" ]; then
                echo "Another start (PID $owner) has been setting up $RUNNER_HOME for 10 minutes, so this one stopped. If that process is not an actions-runner start, remove $lock and start again." >&2
            else
                echo "Could not create the lock $lock for 10 minutes ($err), so this start stopped. Fix the permissions in $RUNNER_HOME, or free space if the disk is full, then start again." >&2
            fi
            exit 1
        fi
        sleep 1; waited=$((waited + 1))
    done
    trap 'rm -f "$lock"' EXIT
}
unlock_home() {
    rm -f "$lock"; trap - EXIT
}
prepare_home() {
    if [ -z "${RUNNER_HOME:-}" ]; then
        echo "RUNNER_HOME is not set. Set RUNNER_HOME to an empty directory or to a runner directory, then start again." >&2; exit 1
    fi
    if home_current; then return; fi
    if ! mkdir -p "$RUNNER_HOME"; then
        echo "Could not create the runner directory $RUNNER_HOME (the error is above). Set RUNNER_HOME to an empty directory or to a runner directory, then start again." >&2; exit 1
    fi
    local home exe target pid
    home=$(cd "$RUNNER_HOME" && pwd -P) || exit 1
    lock_home "$home"
    # Another start may have set the home up while this one waited for the lock.
    if home_current; then unlock_home; return; fi
    if [ -e "$home/bin" ] || [ -e "$home/externals" ]; then
        if [ ! -e "$home/bin/Runner.Listener" ] && [ ! -e "$home/.minimal-copying" ]; then
            echo "$RUNNER_HOME has a bin/ or externals/ directory but no runner (no bin/Runner.Listener), so nothing was changed in it. Set RUNNER_HOME to an empty directory or to a runner directory, then start again." >&2
            unlock_home; exit 1
        fi
        for exe in /proc/[0-9]*/exe; do
            target=$(readlink "$exe" 2>/dev/null) || continue
            case "$target" in
                "$home"/bin*/Runner.*)
                    pid=${exe#/proc/}; pid=${pid%/exe}
                    echo "A runner from $RUNNER_HOME is still running (PID $pid). Stop it, then start it again to upgrade it to the packaged runner." >&2
                    unlock_home; exit 1 ;;
            esac
        done
        echo "Upgrading the runner in $RUNNER_HOME to the packaged one ($(cut -d' ' -f1-4 "$pkg/.minimal-package-stamp")). The registration and _work are kept." >&2
        if ! { : > "$home/.minimal-copying" &&
            rm -f "$home/.minimal-installed-stamp" &&
            rm -rf "${home:?}/bin" "${home:?}/externals" "${home:?}"/bin.* "${home:?}"/externals.*; }; then
            echo "Could not remove the old runner from $RUNNER_HOME. Fix the permissions there, then start again." >&2
            unlock_home; exit 1
        fi
    else
        echo "Setting up writable runner directory at $RUNNER_HOME..." >&2
        if ! : > "$home/.minimal-copying"; then
            echo "Could not write to $RUNNER_HOME. Fix the permissions there, then start again." >&2
            unlock_home; exit 1
        fi
    fi
    if ! { cp -a "$pkg/." "$home/" &&
        cp "$pkg/.minimal-package-stamp" "$home/.minimal-installed-stamp" &&
        rm -f "$home/.minimal-copying"; }; then
        echo "Could not copy the packaged runner into $RUNNER_HOME (is the disk full?). Free space there, then start again: the next start copies it again." >&2
        unlock_home; exit 1
    fi
    unlock_home
}
# CVE-2026-111943: the bundled externals/node{20,24} trust their compiled-in
# root store, which still holds emSign ECC Root CA - G3. --use-openssl-ca
# makes them trust OpenSSL's default store instead, i.e. our ca-certificates
# (/etc/ssl/cert.pem). The runner's processes inherit this environment, so
# JavaScript actions and node in `run:` steps get it too. A workflow that sets
# its own NODE_OPTIONS replaces it for its steps; one that already chose a
# store keeps its choice.
case " ${NODE_OPTIONS:-} " in
    *" --use-openssl-ca "*|*" --use-bundled-ca "*) ;;
    *) export NODE_OPTIONS="--use-openssl-ca${NODE_OPTIONS:+ $NODE_OPTIONS}" ;;
esac
EOF

# actions-runner: run.sh, with self-update off at every start.
#
# A self-update replaces bin/ with upstream's .NET 8 build, which cannot load
# OpenSSL 4 (see above). On every message poll the runner tells the server
# whether it takes updates, from `disableUpdate` in its settings (upstream
# MessageListener / BrokerMessageListener pass _settings.DisableUpdate to
# GetAgentMessage / GetRunnerMessage). So every start sets it in .runner and in
# .runner_migrated (upstream Runner.cs uses the migrated settings when that
# file exists and its session starts), which also covers runners registered
# before this package added --disableupdate. A JIT runner writes .runner at
# start from its jitconfig, so the field is set inside that value: every
# `--jitconfig <value>` argument (the option name in any case, as upstream's
# CommandLineParser reads it), or else ACTIONS_RUNNER_INPUT_JITCONFIG (any
# case, as upstream CommandSettings reads it; the command line wins). Upstream
# does not read `--jitconfig=<value>`, so the wrapper leaves it alone. The value
# is a secret (it holds .credentials and the RSA key), so it reaches node on
# stdin, not on node's command line. If the field cannot be set, the runner
# does not start.
{
  echo '#!/bin/bash'
  cat prelude.sh
  cat << 'EOF'
no_update_js='
const fs = require("fs");
const path = require("path");
// Every number must serialize back to its exact source text, or the rewrite
// would change it (a JS number is exact only to 2^53; agentId is a ulong).
// JSON.parse source access (context.source) is in V8 since 11.4; node24 has 13.6.
// Without it, or on any mismatch, nothing is written and the start is refused.
const exact = function (key, value, context) {
  if (typeof value === "number") {
    if (!context || typeof context.source !== "string") throw new Error("this node has no JSON.parse source access");
    if (String(value) !== context.source || (/^-?[0-9]+$/.test(context.source) && !Number.isSafeInteger(value)))
      throw new Error("number " + context.source + " at \"" + key + "\" would not survive a rewrite");
  }
  return value;
};
const off = (text) => {
  const o = JSON.parse(text.replace(/^\uFEFF/, ""), exact);
  if (o === null || typeof o !== "object" || Array.isArray(o)) throw new Error("the runner settings are not a JSON object");
  o.disableUpdate = true;
  return JSON.stringify(o, null, 2);
};
const [mode, arg] = process.argv.slice(1);
try {
  if (mode === "file") {
    // A temporary file of its own in the same directory, with the mode of the
    // file it replaces, renamed over it only once it is complete.
    const next = off(fs.readFileSync(arg, "utf8"));
    const perm = fs.statSync(arg).mode & 0o7777;
    const tmp = path.join(path.dirname(arg), "." + path.basename(arg) + "." + require("crypto").randomBytes(8).toString("hex"));
    let created = false;
    try {
      fs.writeFileSync(tmp, next, { flag: "wx", mode: 0o600 });
      created = true;
      fs.chmodSync(tmp, perm);
      fs.renameSync(tmp, arg);
    } catch (e) {
      if (created) try { fs.unlinkSync(tmp); } catch (_) {}
      throw e;
    }
  } else if (mode === "jit") {
    const m = JSON.parse(Buffer.from(fs.readFileSync(0, "utf8").trim(), "base64").toString("utf8"));
    if (m === null || typeof m !== "object" || typeof m[".runner"] !== "string") throw new Error("it is not base64 JSON with a .runner entry");
    m[".runner"] = Buffer.from(off(Buffer.from(m[".runner"], "base64").toString("utf8"))).toString("base64");
    process.stdout.write(Buffer.from(JSON.stringify(m)).toString("base64"));
  } else throw new Error("usage: file <path> | jit (value on stdin)");
} catch (e) {
  console.error("actions-runner: " + e.message);
  process.exit(1);
}
'
no_update_file() { # no_update_file <settings file in RUNNER_HOME>
    "$pkg/externals/node24/bin/node" -e "$no_update_js" file "$1" && return 0
    echo "Could not set disableUpdate in $RUNNER_HOME/$1 (the error is above), so the runner was not started. Restore that file, or register the runner again with actions-runner-config, then start it again." >&2
    exit 1
}
no_update_jit() { # no_update_jit <value> <where it came from>: prints the value with disableUpdate set
    local out
    # printf is a bash builtin: the secret goes to node's stdin, on no command line.
    if out=$(printf '%s' "$1" | "$pkg/externals/node24/bin/node" -e "$no_update_js" jit); then
        printf '%s' "$out"; return 0
    fi
    echo "Could not set disableUpdate in the jitconfig from $2 (the error is above), so the runner was not started. Pass the encoded_jit_config value GitHub returned for this runner, unchanged." >&2
    exit 1
}

prepare_home
cd "$RUNNER_HOME" || exit 1
for f in .runner .runner_migrated; do
    if [ -f "$f" ]; then
        no_update_file "$f"
    fi
done
args=("$@")
cli_jit=0
# As upstream CommandLineParser reads it: the value of --jitconfig is the next
# argument that does not start with "-", unless a "--<name>" comes first.
shopt -s nocasematch
for ((i = 0; i < ${#args[@]}; i++)); do
    [[ ${args[i]} == --jitconfig ]] || continue
    for ((j = i + 1; j < ${#args[@]}; j++)); do
        [[ ${args[j]} == --?* ]] && break
        [[ ${args[j]} == -* ]] && continue
        args[j]=$(no_update_jit "${args[j]}" "${args[i]}") || exit 1
        cli_jit=1
        break
    done
done
if [ "$cli_jit" = 0 ]; then
    while IFS= read -r name; do
        [[ $name == ACTIONS_RUNNER_INPUT_JITCONFIG ]] || continue
        val=${!name}
        # Upstream ignores an empty or blank value.
        [[ -n ${val//[[:space:]]/} ]] || continue
        jit=$(no_update_jit "$val" "$name") || exit 1
        export "$name=$jit"
    done < <(compgen -e)
fi
shopt -u nocasematch
exec ./run.sh "${args[@]}"
EOF
} > "${OUTPUT_DIR}/usr/bin/actions-runner"
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner"

# actions-runner-config: config.sh, registering with updates off unless the
# caller passed --disableupdate itself. `remove` and help take no such flag.
# As upstream reads them: `remove` in any case as the first argument
# (config.sh), and --help in any case or `/?` (CommandLineParser). Flags are
# matched as whole arguments, not inside a value such as `--work "jobs --help"`.
{
  echo '#!/bin/bash'
  cat prelude.sh
  cat << 'EOF'
prepare_home
cd "$RUNNER_HOME" || exit 1
add_flag=1
shopt -s nocasematch
if [[ ${1:-} == remove ]]; then add_flag=0; fi
for a in "$@"; do
    case "$a" in
        --disableupdate|--help|-h|'/?') add_flag=0 ;;
    esac
done
shopt -u nocasematch
if [ "$add_flag" = 1 ]; then
    exec ./config.sh "$@" --disableupdate
fi
exec ./config.sh "$@"
EOF
} > "${OUTPUT_DIR}/usr/bin/actions-runner-config"
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner-config"
