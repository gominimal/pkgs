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
find runner -type f | while read -r f; do
  if head -c 4 "$f" | grep -q 'ELF'; then
    if readelf -d "$f" 2>/dev/null | grep -E 'NEEDED.*\[lib(ssl|crypto)\.so\.3\]'; then
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

# Create wrapper script for run.sh
cat > "${OUTPUT_DIR}/usr/bin/actions-runner" << 'EOF'
#!/bin/bash
if [ ! -d "$RUNNER_HOME/bin" ]; then
    echo "Setting up writable runner directory at $RUNNER_HOME..." >&2
    cp -a /usr/lib/actions-runner/. "$RUNNER_HOME/"
fi
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
cd "$RUNNER_HOME"
exec ./run.sh "$@"
EOF
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner"

# Create wrapper script for config.sh
cat > "${OUTPUT_DIR}/usr/bin/actions-runner-config" << 'EOF'
#!/bin/bash
if [ ! -d "$RUNNER_HOME/bin" ]; then
    echo "Setting up writable runner directory at $RUNNER_HOME..." >&2
    cp -a /usr/lib/actions-runner/. "$RUNNER_HOME/"
fi
# CVE-2026-111943: same as actions-runner (bundled node -> our ca-certificates).
case " ${NODE_OPTIONS:-} " in
    *" --use-openssl-ca "*|*" --use-bundled-ca "*) ;;
    *) export NODE_OPTIONS="--use-openssl-ca${NODE_OPTIONS:+ $NODE_OPTIONS}" ;;
esac
cd "$RUNNER_HOME"
# A self-update would replace bin/ with upstream's .NET 8 build, which cannot
# load OpenSSL 4 (see build.sh): register with updates off unless the caller
# chose. The package is the update path. `remove` takes no such flag.
case " $* " in
    *" --disableupdate "*|" remove "*|*" --help "*|*" -h "*) exec ./config.sh "$@" ;;
    *) exec ./config.sh "$@" --disableupdate ;;
esac
EOF
chmod +x "${OUTPUT_DIR}/usr/bin/actions-runner-config"
