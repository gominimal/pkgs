#!/bin/sh
set -e

# Security backports — CVEs fixed upstream after the 1.25.0 release (see
# build.ncl for provenance). `set -e` plus patch's non-zero exit on a rejected
# hunk means a stale patch ABORTS the build rather than silently shipping an
# unpatched wget. Each touches a different src/ file, so order is immaterial.
patch -Np1 -i "CVE-2026-58469.patch"   # metalink.c  clean_metalink_string buffer underflow
patch -Np1 -i "CVE-2026-58470.patch"   # http.c      parse_content_range integer overflow
patch -Np1 -i "CVE-2026-58471.patch"   # url.c       filename-conversion buffer size
patch -Np1 -i "CVE-2026-58472.patch"   # convert.c   html_quote_string integer+buffer overflow
patch -Np1 -i "CVE-2026-15146.patch"   # ftp-basic.c PASV/LPSV address not checked against peer (SSRF)

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make -j$(nproc)

# Regression test for CVE-2026-15146. A fake FTP server, written in gawk (its
# /inet sockets mean no new build dep), answers PASV with 127.0.0.2, which is
# not the peer of the control connection (127.0.0.1). Patched wget refuses the
# reply ("Cannot parse PASV response.") and never contacts 127.0.0.2. Unpatched
# wget opens its data connection to whatever address the server names: the SSRF.
PORT=$((20000 + $$ % 20000))
cat > ftp-pasv-spoof.awk <<'AWK'
BEGIN {
  srv = "/inet/tcp/" port "/0/0"
  ORS = "\r\n"
  for (;;) {
    print "220 fake ftp" |& srv; fflush(srv)
    while ((srv |& getline line) > 0) {
      sub(/\r$/, "", line)
      cmd = toupper(substr(line, 1, 4))
      if (cmd == "USER") reply = "331 password please"
      else if (cmd == "PASS") reply = "230 logged in"
      else if (cmd == "SYST") reply = "215 UNIX Type: L8"
      else if (cmd == "PWD") reply = "257 \"/\""
      else if (cmd == "TYPE") reply = "200 ok"
      else if (cmd == "CWD ") reply = "250 ok"
      else if (cmd == "SIZE") reply = "213 4"
      else if (cmd == "PASV") reply = "227 Entering Passive Mode (127,0,0,2,0,9)"
      else if (cmd == "QUIT") reply = "221 bye"
      else reply = "502 not implemented"
      print reply |& srv; fflush(srv)
      if (cmd == "QUIT") break
    }
    close(srv)
  }
}
AWK
gawk -v port="$PORT" -f ftp-pasv-spoof.awk &
FAKE_FTP=$!
# Wait until it listens. The probe connection is answered and dropped, and the
# server loops back to accept the next one.
i=0
until bash -c "exec 3<>/dev/tcp/127.0.0.1/$PORT" 2>/dev/null; do
  i=$((i + 1))
  [ "$i" -lt 100 ] || { echo "fake FTP server never listened"; exit 1; }
  sleep 0.1
done
timeout 60 ./src/wget --no-config --no-proxy --tries=1 --passive-ftp \
  -O /dev/null "ftp://127.0.0.1:$PORT/file" > ftp-pasv-spoof.log 2>&1 || true
kill "$FAKE_FTP" 2>/dev/null || true
cat ftp-pasv-spoof.log
grep -q "Cannot parse PASV response" ftp-pasv-spoof.log
if grep -q "127\.0\.0\.2" ftp-pasv-spoof.log; then
  echo "CVE-2026-15146 regression: wget followed a spoofed PASV address"
  exit 1
fi
rm -f ftp-pasv-spoof.awk ftp-pasv-spoof.log

make DESTDIR="$OUTPUT_DIR" install
