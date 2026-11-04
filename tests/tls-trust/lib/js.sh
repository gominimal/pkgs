# lib/js.sh: node, node --use-system-ca, bun, deno, deno with the system store.
# All five run lib/probe.mjs; see its header for what offline proves.

js() { to "$@" 2>&1 | tail -3; return 0; }

live_node()       { js node "$LIB/probe.mjs" live "https://$1/" "$TIMEOUT"; }
off_node()        { js node "$LIB/probe.mjs" offline "$1"; }
live_node_sysca() { js node --use-system-ca "$LIB/probe.mjs" live "https://$1/" "$TIMEOUT"; }
off_node_sysca()  { js node --use-system-ca "$LIB/probe.mjs" offline "$1"; }
live_bun()        { js bun "$LIB/probe.mjs" live "https://$1/" "$TIMEOUT"; }
# bun's fetch trusts its compiled-in roots AND the system store: at the pre-fix
# pin it connected to the AAA hosts, and AAA is in no compiled-in list. So
# offline is the union of tls.rootCertificates and openssl's default paths.
off_bun()         { marker_union "$(js bun "$LIB/probe.mjs" offline "$1")" "$(off_openssl "$1")"; }
live_deno()       { js env DENO_DIR="$W/deno" DENO_NO_UPDATE_CHECK=1 deno run -A "$LIB/probe.mjs" live "https://$1/" "$TIMEOUT"; }
off_deno()        { js env DENO_DIR="$W/deno" DENO_NO_UPDATE_CHECK=1 deno run -A "$LIB/probe.mjs" offline "$1"; }
live_deno_sys()   { js env DENO_TLS_CA_STORE=system DENO_DIR="$W/deno" DENO_NO_UPDATE_CHECK=1 deno run -A "$LIB/probe.mjs" live "https://$1/" "$TIMEOUT"; }

# blocklist variant: NODE_EXTRA_CA_CERTS adds the profile's anchors, so only
# node's in-handshake kBlockedSPKIs check can refuse. No offline equivalent.
live_node_bl()    { NODE_EXTRA_CA_CERTS=$PROFILE/chains/anchors.pem live_node "$1"; }

NODE_NOTE="anchor: tls.getCACertificates('default') membership + signature links; the kBlockedSPKIs half is live-only"
row node          node "node --version"                        live_node       off_node       "$NODE_NOTE"
row node-blocklist node "echo node, anchors trusted"     live_node_bl    -              "N/A (live-only): kBlockedSPKIs fires only inside a handshake"
row node-sysca    node "echo node --use-system-ca"             live_node_sysca off_node_sysca "$NODE_NOTE"
row bun           bun  "bun --version"                         live_bun        off_bun        "anchor+store: tls.rootCertificates links, union openssl verify over the system paths"
row deno          deno "deno --version | head -1 | cut -d' ' -f1-2" live_deno  off_deno       "anchor: node:tls store membership + signature links"
row deno-sysstore deno "echo DENO_TLS_CA_STORE=system"         live_deno_sys   -              "N/A (live-only): node:tls does not reflect DENO_TLS_CA_STORE"
