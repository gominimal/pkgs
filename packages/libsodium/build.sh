#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

# Fix GCC on aarch64: ipcrypt_armcrypto.c uses signed NEON intrinsics and
# stores uint8x16_t in uint64x2_t variables. GCC rejects the implicit
# conversions that Clang allows. Fixed upstream after 1.0.21 (commit 91fe8a46).
if [ "$(uname -m)" = "aarch64" ]; then
  # Fix BYTESHL128 macro: use unsigned intrinsics instead of signed
  sed -i 's/vextq_s8(vdupq_n_s8(0), vreinterpretq_s8_u64/vextq_u8(vdupq_n_u8(0), vreinterpretq_u8_u64/' \
    src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
  # Fix pfx_shift_left: use uint8x16_t for byte-level intermediates
  sed -i 's/const BlockVec shl     /const uint8x16_t shl     /' src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
  sed -i 's/const BlockVec msb     /const uint8x16_t msb     /' src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
  sed -i 's/const BlockVec zero    /const uint8x16_t zero    /' src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
  sed -i 's/const BlockVec carries /const uint8x16_t carries /' src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
  sed -i 's/vextq_u8(vreinterpretq_u8_u64(msb), zero/vextq_u8(msb, zero/' src/libsodium/crypto_ipcrypt/ipcrypt_armcrypto.c
fi

./configure --prefix=/usr --disable-static
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
