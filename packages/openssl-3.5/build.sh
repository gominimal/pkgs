#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# OpenSSL's November 2026 security fixes (advisories of 2026-11-10 and 2026-11-17, all
# rated Low), carried as patches because 3.5.10 is announced but not released. Each patch
# is upstream's own commit on the openssl-3.5 branch (the one the advisory links), unchanged
# unless noted, applied in the order it landed on that branch. -F0 refuses fuzzy hunks.
# Every file a patch touches is hashed before and after, so a different tarball fails
# here instead of patching the wrong file, and a partial apply cannot pass.
# Drop this whole block (and the cve-*.patch files) when version >= 3.5.10.

# CVE-2026-88823: AES-GCM-SIV AAD forgery after a zero-length incremental AAD update.
# https://github.com/openssl/openssl/commit/159e1de0c448d7b9f09ad768c8e141def4aa1eb4
echo "25012f573a36a465f0a68fe004366ef586f3a153d60a5a53db55df9b7b1da5c3  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "37f4e407d03117c6b74e5d1385efb233f2d71225788f82857bff2368e7fd0457  providers/implementations/ciphers/cipher_aes_gcm_siv_hw.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-88823.patch
echo "1c9190d4dfbb2fd767c588376167358e7fd32b135aad0827b8d2cd6b78d69793  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "d5ea349bd8c5d48634b3a6006f1a1ef233213564ee675ee2fce4faec824cc639  providers/implementations/ciphers/cipher_aes_gcm_siv_hw.c" | sha256sum -c -

# CVE-2026-107496: infinite loop in CMS_encrypt() with an EC group order of 1.
# https://github.com/openssl/openssl/commit/a0051cfe699bf5a047bc1c4faef65f80f7987366
echo "76ffd45abfc989d3f5a7c80e71e7ff712cff2c1b3c70f471a5f952190b545bf2  crypto/ec/ec_key.c" | sha256sum -c -
echo "eec366891a69eb9d2de9d814abd51b2c9aa4db2ef51ca19dbc1869a48a446bfe  test/ectest.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-107496.patch
echo "72726357d1e33de2fdc28da42781bb489d4a87762ed308ce81e0c49feaaa82bb  crypto/ec/ec_key.c" | sha256sum -c -
echo "404248bb6baaffa0ba1663cd21be5df7bd65e17c283591b29ab2664cc1ed6582  test/ectest.c" | sha256sum -c -

# CVE-2026-88822: QUIC uses uninitialised stack bytes during automated peer detection.
# https://github.com/openssl/openssl/commit/1a73dc590cbad62d6f0329ea4779eadaa8d8fd75
echo "25ac92a4db74c85b0d096860112c822a1c3b9e07f35ded77b88bfe891c3c7993  crypto/bio/bss_dgram.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-88822.patch
echo "9b0e09c21fdc0ae8c253d1a7aed1114814090d83f92c1ae6e2d83a28c829cb64  crypto/bio/bss_dgram.c" | sha256sum -c -

# CVE-2026-95692: out-of-bounds read and wrong IV length handling in AES-GCM-SIV.
# https://github.com/openssl/openssl/commit/257a3427aa0ef8d9dd2ef5b3e2d1c021a221b116
echo "1c9190d4dfbb2fd767c588376167358e7fd32b135aad0827b8d2cd6b78d69793  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-95692.patch
echo "62510edfb867c2c33b034ec7f1f04913551827441a0f156966bc857cc271c211  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -

# CVE-2026-95691: retransmitted QUIC CRYPTO frames can cause DoS or a one-byte disclosure.
# https://github.com/openssl/openssl/commit/f6244675833e097c2429a40d1b206d95385bd42f
echo "6dd9e3268036cd44869e40616e302c033902de6155a57c696420a75c83f0f457  include/internal/quic_strm_reas.h" | sha256sum -c -
echo "1d75050a351302038ffc4868c253cb73caaf202f1b91da7fbceb62514c712297  ssl/quic/quic_rstream.c" | sha256sum -c -
echo "040b6e3c0cc3144616d3c899a79b90f70a9517a5fb215a10f38b483499360c4c  ssl/quic/quic_strm_reas.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-95691.patch
echo "23cddd86dd8ed5246bca7f668197e73cec4a2653e476310a1d6a34ee243f4d1f  include/internal/quic_strm_reas.h" | sha256sum -c -
echo "ca832c01b754e6556d0d29ee667616102870bb93be2c21e5845e461861b21c31  ssl/quic/quic_rstream.c" | sha256sum -c -
echo "9ed4d3ab6508b79c04033ebb793c0fbcce5615e75323022de20bf2748f74c319  ssl/quic/quic_strm_reas.c" | sha256sum -c -

# CVE-2026-107493: use-after-free in PEM_X509_INFO_read_bio_ex() when appending to a caller-supplied stack fails.
# https://github.com/openssl/openssl/commit/c8f6d04f8e6d40b1bf83334e4a2ec9daf5943a3d
echo "62da2460ad5fa302cf86bf8f9932ba6ae4b40cb67eb0a5e4290458692176c2f1  crypto/pem/pem_info.c" | sha256sum -c -
echo "95ab31b288d04831ae6bd350490cda3749d5802cedb5d30b0df31a1531c8cf08  test/x509_check_cert_pkey_test.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-107493.patch
echo "25b5bdecc831e734fd3af3d8b1222883929a57f4f15fa44190c0e4f88376a475  crypto/pem/pem_info.c" | sha256sum -c -
echo "fd7408c4e2fc6b87d5ce8c1b7c9264d16212cb855250b41445730fa5b6c059d2  test/x509_check_cert_pkey_test.c" | sha256sum -c -

# CVE-2026-35190: out-of-bounds read in TLS 1.3 key-share processing with the Suite B flag.
# https://github.com/openssl/openssl/commit/9491b0d9cc7950af1f3dc89499bd5433b9cd4f43
echo "2b7eb5ec78bdae624ab1b26c52a76810b45962d6ce26925a472d8ebebdaceeaa  ssl/statem/extensions_srvr.c" | sha256sum -c -
echo "96a137ed0cb866f6fecc11ffbeed269321bce3fffc01af1d72e519d251448584  ssl/t1_lib.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-35190.patch
echo "004fb384e61fd3ca36d12c7d83baa29fa5ed42950ab727e3d19504f97f5606f6  ssl/statem/extensions_srvr.c" | sha256sum -c -
echo "3a5988443e2b6cd6aac52ab1438b5f211cab83864cbed90b32b0feba60ff5652  ssl/t1_lib.c" | sha256sum -c -

# CVE-2026-124709: unbounded memory retention in a QUIC server for rejected streams.
# https://github.com/openssl/openssl/commit/f3acb0a3328046741479482c51cec815839e1b05
echo "8bc3bb3585d4131f25fadc1010d6367eb8085670c4d8cf814a62892e6f257088  ssl/quic/quic_stream_map.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-124709.patch
echo "7bceb5bdc408c3e5a46eb38944f5d16727b812e3e049dae6f2b2e4cdadce3616  ssl/quic/quic_stream_map.c" | sha256sum -c -

PREFIX=/usr/lib/openssl-3.5

# Same flags as packages/openssl except the prefix. OPENSSLDIR stays /etc/ssl so the CA
# store and openssl.cnf are shared; MODULESDIR / ENGINESDIR follow libdir into $PREFIX/lib.
./config --prefix="$PREFIX"     \
         --openssldir=/etc/ssl  \
         --libdir=lib           \
         shared                 \
         zlib-dynamic

make -j$(nproc)
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
# install_sw = install_dev install_engines install_modules install_runtime: libraries,
# headers, pkgconfig, cmake, engines, modules and programs. It does not write OPENSSLDIR
# (that is install_ssldirs) or the docs.
make DESTDIR="$OUTPUT_DIR" install_sw

P="$OUTPUT_DIR$PREFIX"
# The CLI belongs to packages/openssl (/usr/bin/openssl, 4.x). Nothing under bin/ is an
# output; delete it so the tree holds only what the outputs capture.
find "$P/bin" -mindepth 1 -delete
rmdir "$P/bin"
find "$P/lib" -maxdepth 1 -name '*.a' -delete

# Runtime sonames onto the default loader path; the dev tree keeps link-time symlinks.
mkdir -p "$OUTPUT_DIR/usr/lib"
for l in libssl libcrypto; do
  mv "$P/lib/$l.so.3" "$OUTPUT_DIR/usr/lib/$l.so.3"
  ln -sfn "../../$l.so.3" "$P/lib/$l.so"
done

# Fail closed on the layout the outputs and consumers rely on.
test -e "$OUTPUT_DIR/usr/lib/libssl.so.3"
test -e "$OUTPUT_DIR/usr/lib/libcrypto.so.3"
test -e "$P/lib/libssl.so"
test -e "$P/include/openssl/opensslv.h"
test -e "$P/lib/pkgconfig/openssl.pc"
test -e "$P/lib/ossl-modules/legacy.so"
grep -qE '^# *define OPENSSL_VERSION_MINOR +5$' "$P/include/openssl/opensslv.h"
