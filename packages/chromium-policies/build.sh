#!/bin/bash
set -euo pipefail

# Installs Chromium enterprise policy for every Chromium-branded browser in the
# tree. See build.ncl for why this is a package and which binaries read it.
#
# The checks below run on every build, so a policy file that would not do its
# job never ships.

POLICY=ca-distrusted-certificates.json

# The SPKI SHA-256 of every key the policy must distrust, one line each:
# "<spki sha256> <name>". CADistrustedCertificates matches by SPKI, so one
# certificate per key covers every certificate for that key (the emSign-issued
# copy, the Sectigo AAA cross-sign, and the ECDSA-malleated twins).
# Keep in step with packages/ca-certificates/distrust.txt (`spki` lines);
# .github/scripts/chromium_policy_distrust_check.py enforces that in CI.
EXPECTED_SPKIS='
ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105 EM DV TLS CA - G3B
e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41 EM EV TLS CA - G3B
ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6 EM OV CS CA - G3B
43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b EM OV TLS CA - G3B
49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f EM DV TLS CA - G3C
5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0 EM EV TLS CA - G3C
92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30 EM OV CS CA - G3C
63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8 EM OV TLS CA - G3C
8d417db2dd8bf5e3084d1e3f196d583849d81bdd4c00c70b9d39369e96b8c782 emSign ECC Root CA - G3
'

# check_policy <file>: succeeds only if <file> is a JSON object whose only key
# is CADistrustedCertificates, every entry is a base64 DER X.509 certificate,
# no two entries share a key, and the entries' SPKI hashes are exactly
# EXPECTED_SPKIS (nothing missing, nothing extra).
check_policy() {
  local file=$1 work spki got want n
  work=$(mktemp -d)

  if ! jq -e 'type == "object" and (keys == ["CADistrustedCertificates"])
              and (.CADistrustedCertificates | type == "array" and length > 0
                   and all(.[]; type == "string"))' "$file" >/dev/null; then
    echo "check_policy: $file is not {\"CADistrustedCertificates\": [<non-empty list of strings>]}" >&2
    rm -rf "$work"
    return 1
  fi

  n=0
  : >"$work/got"
  while IFS= read -r b64; do
    n=$((n + 1))
    if ! printf '%s' "$b64" | base64 -d >"$work/$n.der" 2>/dev/null; then
      echo "check_policy: entry $n is not valid base64" >&2
      rm -rf "$work"
      return 1
    fi
    if ! openssl x509 -inform DER -in "$work/$n.der" -noout -pubkey >"$work/$n.pub" 2>/dev/null; then
      echo "check_policy: entry $n is not a DER X.509 certificate" >&2
      rm -rf "$work"
      return 1
    fi
    spki=$(openssl pkey -pubin -in "$work/$n.pub" -outform DER | sha256sum | cut -d' ' -f1)
    echo "$spki" >>"$work/got"
  done < <(jq -r '.CADistrustedCertificates[]' "$file")

  if [ "$(sort "$work/got" | uniq -d | wc -l)" -ne 0 ]; then
    echo "check_policy: two entries share a key:" >&2
    sort "$work/got" | uniq -d >&2
    rm -rf "$work"
    return 1
  fi

  got=$(sort "$work/got")
  want=$(printf '%s\n' "$EXPECTED_SPKIS" | sed '/^$/d' | cut -d' ' -f1 | sort)
  rm -rf "$work"
  if [ "$got" != "$want" ]; then
    echo "check_policy: SPKI set differs from EXPECTED_SPKIS" >&2
    diff <(echo "$want") <(echo "$got") >&2 || true
    return 1
  fi
  return 0
}

# --- 1. The shipped policy passes. --------------------------------------------
check_policy "$POLICY"

# --- 2. Negative controls: the check must reject broken policies, so a check
# that always passes cannot go unnoticed. -----------------------------------
expect_reject() {
  local label=$1 file=$2
  if check_policy "$file" 2>/dev/null; then
    echo "FAIL: negative control '$label' was accepted; check_policy is broken" >&2
    exit 1
  fi
}
jq '.CADistrustedCertificates |= .[1:]' "$POLICY" >neg-missing.json
expect_reject "one key missing" neg-missing.json
jq '.CADistrustedCertificates += [.CADistrustedCertificates[0]]' "$POLICY" >neg-dup.json
expect_reject "duplicate key" neg-dup.json
jq '.CADistrustedCertificates[0] = "bm90IGEgY2VydGlmaWNhdGU="' "$POLICY" >neg-notcert.json
expect_reject "entry is not a certificate" neg-notcert.json
jq '{CADistrustedCertificate: .CADistrustedCertificates}' "$POLICY" >neg-key.json
expect_reject "misspelled policy name" neg-key.json
jq '. + {Unexpected: true}' "$POLICY" >neg-extra.json
expect_reject "extra policy in this file" neg-extra.json

# --- 3. Install. ---------------------------------------------------------------
# Chromium-branded builds read /etc/chromium/policies/managed/*.json
# (components/policy/core/common/policy_paths.cc). Chrome-branded builds would
# read /etc/opt/chrome/policies, Chrome for Testing /etc/opt/chrome_for_testing
# /policies; nothing in the tree reads those, so they are not installed.
install -d "$OUTPUT_DIR/etc/chromium/policies/managed"
install -m 0644 "$POLICY" "$OUTPUT_DIR/etc/chromium/policies/managed/$POLICY"

echo "chromium-policies: $POLICY passes ($(jq '.CADistrustedCertificates | length' "$POLICY") keys); 5 negative controls rejected"
