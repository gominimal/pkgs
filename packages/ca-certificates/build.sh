#!/bin/sh
# Builds /etc/ssl/certs from curl's Mozilla-derived CA bundle (cacert-<date>.pem,
# https://curl.se/docs/caextract.html), then refuses to finish if the result trusts
# anything in distrust.txt or fails the chain tests below.
#
# Output layout. The bundle, the per-root files and the hash links are all generated
# from the one source, and step 4 asserts they hold exactly the same certificates:
#   etc/ssl/certs/ca-certificates.crt   every trusted root, PEM, one file
#                                       (gnutls's default trust file; Go, rustls, bun)
#   etc/ssl/certs/<Label>.crt           one PEM per root, Debian-style names
#   etc/ssl/certs/<subject-hash>.<n>    OpenSSL CApath links (curl --with-ca-path,
#                                       openssl, python ssl, git, wget, ruby)
#   etc/ssl/cert.pem                    -> certs/ca-certificates.crt; OpenSSL's default
#                                       CAfile, since openssl is built --openssldir=/etc/ssl
set -eu

SRC=$(ls cacert-*.pem)
DISTRUST=distrust.txt
CERTS="$OUTPUT_DIR/etc/ssl/certs"
WORK=$(pwd)/work
mkdir -p "$CERTS" "$WORK"
export LC_ALL=C

# --- 1. Split the bundle into one file per root. ----------------------------------
# curl's format is: "<Label>" line, "====" underline, optional "# ..." lines, PEM.
# File names follow Debian's certdata2pem: ' ' '/' ',' -> '_', '(' ')' -> '='.
awk -v dir="$CERTS" '
  /^=+$/ { label = prev; next }
  /^-----BEGIN CERTIFICATE-----$/ {
    if (label == "") { print "certificate without a label" > "/dev/stderr"; exit 1 }
    name = label
    gsub(/[ \/,]/, "_", name); gsub(/[()]/, "=", name)
    out = dir "/" name ".crt"
    if (out in seen) { print "duplicate label: " label > "/dev/stderr"; exit 1 }
    seen[out] = 1; inpem = 1
  }
  inpem { print > out }
  /^-----END CERTIFICATE-----$/ { close(out); inpem = 0; label = "" }
  { prev = $0 }
' < "$SRC"

src_count=$(grep -c '^-----BEGIN CERTIFICATE-----$' "$SRC")
file_count=$(ls "$CERTS" | wc -l)
if [ "$src_count" -ne "$file_count" ]; then
  echo "FAIL: $SRC has $src_count certificates but $file_count files were written" >&2
  exit 1
fi

# --- 2. Combined bundle, in file-name order (as Debian's update-ca-certificates). ---
( cd "$CERTS" && cat ./*.crt ) > "$WORK/bundle"
mv "$WORK/bundle" "$CERTS/ca-certificates.crt"

# --- 3. OpenSSL subject-hash links (what c_rehash does): <hash>.0, .1 on collision. -
cd "$CERTS"
for cert in *.crt; do
  [ "$cert" = ca-certificates.crt ] && continue
  hash=$(openssl x509 -hash -noout -in "$cert")
  n=0
  while [ -e "$hash.$n" ]; do n=$((n + 1)); done
  ln -s "$cert" "$hash.$n"
done
cd - >/dev/null

ln -s certs/ca-certificates.crt "$OUTPUT_DIR/etc/ssl/cert.pem"

# --- 4. Distrust gate: no certificate in the output may match distrust.txt. --------
# Every PEM block of every output file is checked (the per-root files AND the
# combined bundle), by certificate SHA-256 and by SubjectPublicKeyInfo SHA-256.
grep -E '^(cert|spki) [0-9a-f]{64}( |$)' "$DISTRUST" | awk '{print $1 " " $2}' > "$WORK/deny"
deny_count=$(($(wc -l < "$WORK/deny")))
if [ "$deny_count" -lt 53 ]; then
  echo "FAIL: distrust.txt parsed to only $deny_count entries; refusing to trust a truncated list" >&2
  exit 1
fi

# fingerprints FILE... -> "cert <hex>" and "spki <hex>" lines for every PEM block.
fingerprints() {
  for f in "$@"; do
    rm -rf "$WORK/split"; mkdir "$WORK/split"
    awk -v d="$WORK/split" '
      /^-----BEGIN CERTIFICATE-----$/ { n++; inpem = 1 }
      inpem { print > (d "/" n ".pem") }
      /^-----END CERTIFICATE-----$/ { close(d "/" n ".pem"); inpem = 0 }
    ' < "$f"   # stdin, not an operand: awk reads "NetLock_Arany_=Class..." as an assignment
    for p in "$WORK"/split/*.pem; do
      [ -e "$p" ] || continue
      # Separate steps, not pipes: set -e would not see an openssl failure inside a
      # pipeline, and the gate would compare the hash of empty input.
      openssl x509 -in "$p" -outform DER -out "$p.der"
      openssl x509 -in "$p" -noout -pubkey -out "$p.pub"
      openssl pkey -pubin -in "$p.pub" -outform DER -out "$p.spki"
      c=$(openssl dgst -sha256 -r "$p.der" | cut -d' ' -f1)
      s=$(openssl dgst -sha256 -r "$p.spki" | cut -d' ' -f1)
      if [ ${#c} -ne 64 ] || [ ${#s} -ne 64 ]; then
        echo "FAIL: could not fingerprint a certificate in $f" >&2
        exit 1
      fi
      echo "cert $c"
      echo "spki $s"
    done
  done
}

# Control for the gate itself: it must fire on the two roots this package used to
# ship. If it can't see those, a clean result below would mean nothing.
fingerprints test-removed-roots.pem > "$WORK/control.fps"
control_hits=$(grep -cxF -f "$WORK/deny" "$WORK/control.fps" || true)
if [ "$control_hits" -ne 4 ]; then
  echo "FAIL: distrust gate control matched $control_hits/4 (cert+spki of 2 roots); the gate is broken" >&2
  exit 1
fi

# Bundle and per-root files are fingerprinted separately: they must be the SAME set
# (the old tarball's bundle and directory disagreed by 34 roots).
( cd "$CERTS" && for c in ./*.crt; do [ "$c" = ./ca-certificates.crt ] || fingerprints "$c"; done ) > "$WORK/files.fps"
fingerprints "$CERTS/ca-certificates.crt" > "$WORK/bundle.fps"
fingerprints "$OUTPUT_DIR/etc/ssl/cert.pem" > "$WORK/certpem.fps"
for fps in files bundle certpem; do
  n=$(grep -c '^cert ' "$WORK/$fps.fps")
  if [ "$n" -ne "$src_count" ]; then
    echo "FAIL: $fps holds $n certificates, expected $src_count" >&2
    exit 1
  fi
  sort "$WORK/$fps.fps" > "$WORK/$fps.sorted"
done
if ! cmp -s "$WORK/files.sorted" "$WORK/bundle.sorted" || ! cmp -s "$WORK/files.sorted" "$WORK/certpem.sorted"; then
  echo "FAIL: ca-certificates.crt, cert.pem and the per-root files differ:" >&2
  diff "$WORK/files.sorted" "$WORK/bundle.sorted" >&2 || true
  exit 1
fi
cat "$WORK/files.fps" "$WORK/bundle.fps" > "$WORK/output.fps"
if grep -xF -f "$WORK/deny" "$WORK/output.fps" > "$WORK/hits"; then
  echo "FAIL: output contains distrusted certificates/keys (see distrust.txt):" >&2
  cat "$WORK/hits" >&2
  exit 1
fi

# --- 5. Chain tests against the finished output. ----------------------------------
BUNDLE="$CERTS/ca-certificates.crt"
bundle_count=$(grep -c '^-----BEGIN CERTIFICATE-----$' "$BUNDLE")
if [ "$bundle_count" -lt 100 ] || [ "$bundle_count" -ne "$src_count" ]; then
  echo "FAIL: bundle has $bundle_count certificates (source $src_count, minimum 100)" >&2
  exit 1
fi

# -no_check_time: the fixtures' leaves expire; these tests are about trust, not dates.
# -no-CAfile/-no-CApath/-no-CAstore: without them `openssl verify` ALSO loads the
# default store of whatever openssl runs the test (e.g. an old /etc/ssl/certs), and a
# compromised chain "verifies" through it. Seen on a dry run against Homebrew's store.
# A chain from a compromised intermediate must be rejected for lack of an issuer,
# via both the bundle file and the hashed directory ...
for chain in test-chain-emudhra-emsign.pem test-chain-emudhra-aaa.pem; do
  for store in "-CAfile $BUNDLE -no-CApath -no-CAstore" "-CApath $CERTS -no-CAfile -no-CAstore" \
               "-CAfile $OUTPUT_DIR/etc/ssl/cert.pem -no-CApath -no-CAstore"; do
    if openssl verify -no_check_time $store -untrusted "$chain" "$chain" > "$WORK/v.out" 2>&1; then
      echo "FAIL: $chain VERIFIES against $store (CVE-2026-111943 not fixed):" >&2
      cat "$WORK/v.out" >&2
      exit 1
    fi
    if ! grep -q 'unable to get local issuer certificate' "$WORK/v.out"; then
      echo "FAIL: $chain was rejected by $store for an unexpected reason:" >&2
      cat "$WORK/v.out" >&2
      exit 1
    fi
  done
  # ... and must verify once the removed roots are added back, so the rejection above
  # is caused by their removal and not by a broken fixture.
  cat "$BUNDLE" test-removed-roots.pem > "$WORK/with-removed.pem"
  if ! openssl verify -no_check_time -CAfile "$WORK/with-removed.pem" -no-CApath -no-CAstore -untrusted "$chain" "$chain" > "$WORK/v.out" 2>&1; then
    echo "FAIL: control: $chain does not verify even with the removed roots; fixture is broken:" >&2
    cat "$WORK/v.out" >&2
    exit 1
  fi
done

# A legitimate chain must still verify, via the bundle and via the hash links.
for good in test-good-letsencrypt-r12.pem test-good-letsencrypt-e7.pem; do
  for store in "-CAfile $BUNDLE -no-CApath -no-CAstore" "-CApath $CERTS -no-CAfile -no-CAstore" \
               "-CAfile $OUTPUT_DIR/etc/ssl/cert.pem -no-CApath -no-CAstore"; do
    if ! openssl verify -no_check_time $store "$good" > "$WORK/v.out" 2>&1; then
      echo "FAIL: legitimate $good does not verify against $store:" >&2
      cat "$WORK/v.out" >&2
      exit 1
    fi
  done
done

echo "ca-certificates: $src_count roots from $SRC; distrust gate clean ($deny_count entries); chain tests passed"
