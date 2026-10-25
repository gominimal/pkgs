let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# giflib: the GIF codec library (libgif.so.7) and its header, as OpenJDK's --with-giflib=system wants them.
# 6.x keeps the libgif.so.7 soname; its one API change is EGifSpew() gaining an
# ErrorCode out-param (plus renumbered E_GIF_ERR_* codes). OpenJDK's splashscreen
# only decodes (DGifOpen / DGifSlurp / DGifCloseFile) and already takes the
# two-arg DGifCloseFile branch for GIFLIB_MAJOR > 5, in every rung 9..25.
let version = "6.1.3" in
{
  name = "giflib",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-26740 (heap OOB write in EGifGCBToSavedExtension): upstream commit
    # 061605081115bbfd7019bafc119a13b6f17fcf25, landed after 6.1.3 and unreleased.
    # Drop on the next giflib release that contains it.
    { file = "0001-CVE-2026-26740-egif-gcb-bounds-check.patch" } | Local,
    {
      # https://downloads.sourceforge.net/project/giflib/giflib-6.x/giflib-6.1.3.tar.gz
      url = "gs://minimal-staging-archives/giflib-%{version}.tar.gz",
      sha256 = "b65b66b99f0424b93525f987386f22fc5efb9da2bfc92ad4a532249aaffbab0e",
      extract = true,
      strip_prefix = "giflib-%{version}",
    } | Source,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libgif.so*" } | OutputLib,
    includes = { glob = "usr/include/gif_lib.h" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "giflib",
      source_provenance = {
        category = 'Sourceforge,
        name = "giflib",
      },
    } | Attrs,
  tests = {
    # Decodes a 1x1 GIF89a from memory the way OpenJDK's splashscreen does
    # (DGifOpen with a read callback, DGifSlurp, DGifSavedExtensionToGCB,
    # two-arg DGifCloseFile), and pins the header to the 6.1.x line that carries
    # the CVE-2026-23868 GifMakeSavedImage double-free fix (6.1.2+).
    decode_like_openjdk =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > t.c << 'EOF'
#include <stdio.h>
#include <string.h>
#include <gif_lib.h>

static const unsigned char GIF[] = {
    'G','I','F','8','9','a', 1,0, 1,0, 0x80, 0, 0,
    0xFF,0x00,0x00, 0x00,0x00,0x00,
    0x21,0xF9,0x04, 0x00, 0x07,0x00, 0x00, 0x00,
    0x2C, 0,0, 0,0, 1,0, 1,0, 0x00,
    0x02, 0x02, 0x44, 0x01, 0x00,
    0x3B };
static size_t off;
static int rd(GifFileType *g, GifByteType *buf, int n) {
    (void)g;
    if (off + (size_t)n > sizeof GIF) n = (int)(sizeof GIF - off);
    memcpy(buf, GIF + off, (size_t)n); off += (size_t)n; return n;
}
int main(void) {
#if !(GIFLIB_MAJOR == 6 && (GIFLIB_MINOR > 1 || GIFLIB_RELEASE >= 2))
#error "expected giflib >= 6.1.2 (CVE-2026-23868 fix)"
#endif
    int err = 0;
    GifFileType *g = DGifOpen(NULL, rd, &err);
    if (!g) { printf("DGifOpen: %s\n", GifErrorString(err)); return 1; }
    if (DGifSlurp(g) == GIF_ERROR) { printf("DGifSlurp: %s\n", GifErrorString(g->Error)); return 1; }
    GraphicsControlBlock gcb;
    if (g->SWidth != 1 || g->SHeight != 1 || g->ImageCount != 1) return 2;
    if (g->SavedImages[0].RasterBits[0] != 0) return 3;
    if (g->SColorMap->Colors[0].Red != 0xFF) return 4;
    if (DGifSavedExtensionToGCB(g, 0, &gcb) == GIF_ERROR || gcb.DelayTime != 7) return 5;
    if (DGifCloseFile(g, &err) == GIF_ERROR) return 6;
    printf("OK\n");
    return 0;
}
EOF
          gcc -Wall -Werror t.c -o t -lgif
          ./t | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,

    # CVE-2026-26740 regression: a saved image whose Graphics Control Extension
    # block holds fewer than 4 bytes. Stock 6.1.3 writes the 4-byte GCB into it
    # (heap OOB write) and returns GIF_OK; with upstream commit 0616050 it
    # returns GIF_ERROR and leaves the block alone. Passes only with the patch.
    gcb_to_short_extension_rejected =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > t.c << 'EOF'
#include <stdio.h>
#include <string.h>
#include <gif_lib.h>

static const unsigned char GIF[] = {
    'G','I','F','8','9','a', 1,0, 1,0, 0x80, 0, 0,
    0xFF,0x00,0x00, 0x00,0x00,0x00,
    0x2C, 0,0, 0,0, 1,0, 1,0, 0x00,
    0x02, 0x02, 0x44, 0x01, 0x00,
    0x3B };
static size_t off;
static int rd(GifFileType *g, GifByteType *buf, int n) {
    (void)g;
    if (off + (size_t)n > sizeof GIF) n = (int)(sizeof GIF - off);
    memcpy(buf, GIF + off, (size_t)n); off += (size_t)n; return n;
}
int main(void) {
    int err = 0;
    GifFileType *g = DGifOpen(NULL, rd, &err);
    if (!g || DGifSlurp(g) == GIF_ERROR) { printf("decode failed\n"); return 1; }
    SavedImage *si = &g->SavedImages[0];
    unsigned char two[2] = { 0xAA, 0xBB };
    if (GifAddExtensionBlock(&si->ExtensionBlockCount, &si->ExtensionBlocks,
                             GRAPHICS_EXT_FUNC_CODE, 2, two) == GIF_ERROR) return 2;
    GraphicsControlBlock gcb = { DISPOSE_BACKGROUND, false, 100, 0 };
    int rc = EGifGCBToSavedExtension(&gcb, g, 0);
    ExtensionBlock *ep = &si->ExtensionBlocks[si->ExtensionBlockCount - 1];
    if (rc != GIF_ERROR) { printf("FAIL: short GCE block accepted (rc=%d)\n", rc); return 3; }
    if (ep->ByteCount != 2 || ep->Bytes[0] != 0xAA || ep->Bytes[1] != 0xBB) { printf("FAIL: block modified\n"); return 4; }
    DGifCloseFile(g, &err);
    printf("OK\n");
    return 0;
}
EOF
          gcc -Wall -Werror t.c -o t -lgif
          ./t
          ./t | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
