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
# rated Low), carried as patches because 4.1.1 is announced but not released. Each patch
# is upstream's own commit on the openssl-4.1 branch (the one the advisory links), unchanged
# unless noted, applied in the order it landed on that branch. -F0 refuses fuzzy hunks.
# Every file a patch touches is hashed before and after, so a different tarball fails
# here instead of patching the wrong file, and a partial apply cannot pass.
# Drop this whole block (and the cve-*.patch files) when version >= 4.1.1.

# CVE-2026-88823: AES-GCM-SIV AAD forgery after a zero-length incremental AAD update.
# https://github.com/openssl/openssl/commit/6747b1a278816dd7db46438040a70b0b5e5e0a90
echo "c3895e5269761724f496384eb777d6976eb59865f192c2c29a09f7fe60d129ac  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "7810931b9c155b07ae088f489bbbb9744ef538de0bef9bab096c24984312c31f  providers/implementations/ciphers/cipher_aes_gcm_siv_hw.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-88823.patch
echo "86f9220d0bc43c22d7583a268f0b6f4fd38052fd5e3da3fd803413c7528a6806  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "1b82cf9144b38dc73f116110d3e8890e63f41869d38cdd06268567c9b6d0881c  providers/implementations/ciphers/cipher_aes_gcm_siv_hw.c" | sha256sum -c -

# CVE-2026-107496: infinite loop in CMS_encrypt() with an EC group order of 1.
# https://github.com/openssl/openssl/commit/36e15b618decdff1b116eead6747718e6e729ad2
echo "e96871cdfaf869c649549802d8ff849368fa270b2d9f9ed74a8d1460d10aa40d  crypto/ec/ec_key.c" | sha256sum -c -
echo "a6f49fa34ed2a537e329c3bbac3a37d77f486d7be1c1d9f9ee75be9f678f117e  test/ectest.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-107496.patch
echo "248a2f638fa773e6312afcd984e356dd3841ea4c9148b54005b7337000f678e5  crypto/ec/ec_key.c" | sha256sum -c -
echo "4c0175001bac5a876676a3e9da76cf122862f4372eb8681cbf3b9ebf3de52d64  test/ectest.c" | sha256sum -c -

# CVE-2026-88822: QUIC uses uninitialised stack bytes during automated peer detection.
# https://github.com/openssl/openssl/commit/7b4f5344aa0401e7b777640050b5257ed2a70e88
echo "18ac88130dfae97498ed19f681ef1d504f49e69217a94e265f13ae02be815031  crypto/bio/bss_dgram.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-88822.patch
echo "6d0c22c81decc95d73f88cb041a1c1a214bba40ce7d447d8717532a88095e454  crypto/bio/bss_dgram.c" | sha256sum -c -

# CVE-2026-95692: out-of-bounds read and wrong IV length handling in AES-GCM-SIV.
# https://github.com/openssl/openssl/commit/70a47ac78b6f3be1b22fb1551bd0bfcff4f29613
echo "86f9220d0bc43c22d7583a268f0b6f4fd38052fd5e3da3fd803413c7528a6806  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "8fa6f924d71008460275671d9e0759af22e5c7d6042c2d77e2515657cceaddb6  providers/implementations/ciphers/cipher_aes_gcm_siv.inc.in" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-95692.patch
echo "1fdfc74b3fc7fc41952eeb0e05289f6e62b9e86aae44ee7b34556237e727fefd  providers/implementations/ciphers/cipher_aes_gcm_siv.c" | sha256sum -c -
echo "1e8127ab9c9713588a0246dfefa140facbc0f9a6e47adde4c624079565a3a0f0  providers/implementations/ciphers/cipher_aes_gcm_siv.inc.in" | sha256sum -c -

# CVE-2026-95691: retransmitted QUIC CRYPTO frames can cause DoS or a one-byte disclosure.
# https://github.com/openssl/openssl/commit/dd90ceb99a3c2ddba336bb4a00be9ebabd84c2a1
echo "6dd9e3268036cd44869e40616e302c033902de6155a57c696420a75c83f0f457  include/internal/quic_strm_reas.h" | sha256sum -c -
echo "70ad7e5aa74fc02e1278bd4178af00f07e2bcf8865adc733f95e7a1555e9b041  ssl/quic/quic_rstream.c" | sha256sum -c -
echo "006dbe44217e4fed754ca36d4beae2d1f27c636d469b1fa379f1342ecd6b88a9  ssl/quic/quic_strm_reas.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-95691.patch
echo "23cddd86dd8ed5246bca7f668197e73cec4a2653e476310a1d6a34ee243f4d1f  include/internal/quic_strm_reas.h" | sha256sum -c -
echo "1362cb94762ddad2e1886af3e5e678de2086b67042ea2341ec64bed652810cc4  ssl/quic/quic_rstream.c" | sha256sum -c -
echo "c06273ab380bfe6c65345e381634b8eeae44e11eb9aeaff9e61de13f39176dfb  ssl/quic/quic_strm_reas.c" | sha256sum -c -

# CVE-2026-107493: use-after-free in PEM_X509_INFO_read_bio_ex() when appending to a caller-supplied stack fails.
# https://github.com/openssl/openssl/commit/c57a5ccf0c060755b5494a6870922b7c6cdd7dd8
echo "1dadf34513ab7258a389c51c8a72b1160fe64deed3eeced5a543c550006480c2  crypto/pem/pem_info.c" | sha256sum -c -
echo "95ab31b288d04831ae6bd350490cda3749d5802cedb5d30b0df31a1531c8cf08  test/x509_check_cert_pkey_test.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-107493.patch
echo "6a1786d07caa48dee8a59fb30c6bd4a79bcc562ce4c89c6fb5ed8e36915ec1db  crypto/pem/pem_info.c" | sha256sum -c -
echo "fd7408c4e2fc6b87d5ce8c1b7c9264d16212cb855250b41445730fa5b6c059d2  test/x509_check_cert_pkey_test.c" | sha256sum -c -

# CVE-2026-35190: out-of-bounds read in TLS 1.3 key-share processing with the Suite B flag.
# https://github.com/openssl/openssl/commit/ade64619df04056b3e5fd1c1befe9425a7c80eb6
echo "6d52849bba9ed181dc754f1ecb5d920834c055042e0c2c307017aa8e07d70c43  ssl/statem/extensions_srvr.c" | sha256sum -c -
echo "47b29eb76334c0327e3fc83564ef0504dcda91bf940cd4610bf5fab3e091f132  ssl/t1_lib.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-35190.patch
echo "135d49c40053d47972b66b6dd38dbf0f7457f8176f8111f6f84c98106998feda  ssl/statem/extensions_srvr.c" | sha256sum -c -
echo "e85e0841125b7eca6e6f6e047c93b50fdd13ee1a3a130117d113114b65de6d5e  ssl/t1_lib.c" | sha256sum -c -

# CVE-2026-124709: unbounded memory retention in a QUIC server for rejected streams.
# https://github.com/openssl/openssl/commit/ead311df1037e7994a6d86c7e862d71ad59c52c7
# (code hunk verbatim; upstream's test/quicapitest.c hunks dropped, one does not apply to 4.1.0)
echo "3874dc7267f1528f1f7d7357e5108d7d416b6ee9bf81c0ed38d4178e0148a685  ssl/quic/quic_stream_map.c" | sha256sum -c -
patch -Np1 -F0 -i ./cve-2026-124709.patch
echo "1b98ed7b7ed41ef81b3555aad5c0ab16dd9d209efe0db8cef87326625eb9abd6  ssl/quic/quic_stream_map.c" | sha256sum -c -

./config  --prefix=/usr         \
         --openssldir=/etc/ssl  \
         --libdir=lib           \
         shared                 \
         zlib-dynamic

make -j$(nproc)
# HARNESS_JOBS=$(nproc) make test
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make DESTDIR="$OUTPUT_DIR" MANSUFFIX=ssl install

# 4.x layout, fail-closed: SHLIB_VERSION=4 (libssl.so.4 / libcrypto.so.4, every symbol
# versioned OPENSSL_4.0.0, so a libssl.so.3 from packages/openssl-3.5 can share a process),
# providers under lib/ossl-modules, and no engines or c_rehash (both removed in 4.0).
test -e "$OUTPUT_DIR/usr/lib/libssl.so.4"
test -e "$OUTPUT_DIR/usr/lib/libcrypto.so.4"
test -e "$OUTPUT_DIR/usr/lib/ossl-modules/legacy.so"
