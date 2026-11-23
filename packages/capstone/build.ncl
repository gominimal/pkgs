let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let patch = import "../patch/build.ncl" in
let version = "5.0.9" in
{
  name = "capstone",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
    glibc,
    {
      url = "https://github.com/capstone-engine/capstone/archive/refs/tags/%{version}.tar.gz",
      sha256 = "0619da31af08152600af95c481527ef6d756c0a8404fca7544a4fdf6dfc2c0f9",
      extract = true,
      strip_prefix = "capstone-%{version}",
    } | Source,
    # Security backports. 5.0.9 is the latest v5 release and the fixes below
    # are only on the v5 branch or on next; build.sh applies them fail-closed
    # and then runs cve-regress.c against an ASan build of the patched tree.
    #
    # CVE-2026-55893 (GHSA-3hpv-wr3j-rxwh, SH set_reg_n heap write past the
    # 3-entry operands[]) and CVE-2026-55894 (GHSA-gf2c-xwcp-hvf4, SH decode[]
    # table read out of bounds). Verbatim `git format-patch` of the v5-branch
    # backport e17ee44a (capstone PR #2969). On 5.0.9 both sinks are reached
    # through the decode_long fallthrough below, and ASan confirms both on the
    # stock tree (cve-regress.c sh-fallthrough-* and the reporters' inputs).
    { file = "CVE-2026-55893-55894-sh-bounds.patch" } | Local,
    # GHSA-5q63-4654-94v6 (no CVE yet): SH2A 32-bit decode_long() failure
    # falls through into the 16-bit table with a dirty op_count, and
    # SH_printInst reads operands[3]. Fixed on next by de4b58b2, not yet on
    # v5. Carried: that commit's two-line `else return MCDisassembler_Fail;`
    # only, at v5's offset; the rest of de4b58b2 is assert hardening with a
    # macro v5 lacks, reformatting, and test-file edits (patch header says so).
    # It must come with e17ee44a: that backport replaces opFMOVm's
    # `op_count = 2` with two increments, which is what lets the dirty count
    # reach 4.
    { file = "GHSA-5q63-4654-94v6-sh-decode-long.patch" } | Local,
    # CVE-2026-49282 (GHSA-jrw4-wj52-2vw8), M68K half: M68K_insn_name checks
    # `id > ARR_SIZE(...)`, so cs_insn_name(h, M68K_INS_ENDING) reads one past
    # the table. `git format-patch` of next's 7441aee2 limited to
    # arch/M68K/M68KInstPrinter.c (its other hunk edits a unit test v5 does
    # not have). The RISCV half does not apply to v5: RISCV_insn_name there
    # already returns NULL for id >= RISCV_INS_ENDING (cve-regress.c checks).
    { file = "CVE-2026-49282-m68k-insn-name.patch" } | Local,
    # GHSA-8qp8-2vg2-8mr4 (no CVE), TMS320C64x half: DecodeCrosspathX3 reads
    # Inst->Operands[2].Kind before anything wrote it. v5's cc6f8e07 ("memset
    # MCInst on init", PR #3032) zeroes the whole MCInst, so the unwritten
    # Kind is kInvalid (0) and the RegVal swap is skipped. Verbatim. The ARM
    # half (check_pop_return) is next-only code; v5 has no such function.
    { file = "GHSA-8qp8-2vg2-8mr4-mcinst-memset.patch" } | Local,
    { file = "cve-regress.c" } | Local,
    patch,
  ],
  cmd = "./build.sh",
  outputs = {
    cstool = { glob = "usr/bin/cstool" } | OutputBin,
    libs = { glob = "usr/lib/libcapstone.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    cmake_files = { glob = "usr/lib/cmake/**" } | OutputData,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "capstone-engine", repo = "capstone" },
      # Two licences, both permissive, and the tree ships both files:
      #   LICENSE.TXT       BSD-3-Clause (COSEINC)
      #   LICENSE_LLVM.TXT  University of Illinois/NCSA Open Source License,
      #                     covering the arch decoders generated from LLVM's
      #                     tables. This is the OLD "LLVM Release License" —
      #                     capstone 5.x predates LLVM's relicensing, so it is
      #                     NCSA here, NOT Apache-2.0 WITH LLVM-exception.
      # Recorded as the aggregate rather than the headline licence, since
      # NCSA's attribution clause travels with the binary too.
      license_spdx = "(BSD-3-Clause AND NCSA)",
    } | Attrs,
  tests = {
    smoketest = standaloneTest "/bin/cstool -v",

    # DISASSEMBLE, don't just run --version.
    #
    # The failure this guards is a build that works and is quietly less
    # capable. `CAPSTONE_ARCHITECTURE_DEFAULT` gates every per-arch
    # `CAPSTONE_<ARCH>_SUPPORT` option, so changing one value drops whole
    # architectures out of the library while cstool still builds, still runs,
    # and still reports the same version. Nothing else here would notice:
    # `enumerate bins` sees a binary, `output types valid` sees a .so, a
    # smoke test sees a version string.
    #
    # So the assertions are real instructions on real bytes, including two
    # fringe architectures — the ones a "slim it down" change removes first,
    # and the ones an RE workbench misses last.
    disassembles =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          # x86-64: push rbp / mov rbp, rsp — the universal function prologue.
          ["/bin/bash", "-c", "cstool x64 '554889e5' | grep -qi push && cstool x64 '554889e5' | grep -qi mov"],
          # arm64: mul x1, x1, x2 — capstone's own test vector.
          ["/bin/bash", "-c", "cstool arm64 '217c029b' | grep -qi mul"],
          # 32-bit ARM: a branch-with-link.
          ["/bin/bash", "-c", "cstool arm 'edffffeb' | grep -qi bl"],
          # Fringe #1 — riscv64 (0x00000013 = nop).
          ["/bin/bash", "-c", "cstool riscv64 '13000000' | grep -qiE 'nop|addi'"],
          # Fringe #2 — ppc64, BIG-endian. `ppc64` alone is CS_MODE_LITTLE_ENDIAN
          # in capstone 5 (cstool.c: "ppc64" => CS_MODE_64|CS_MODE_LITTLE_ENDIAN),
          # and 7c0802a6 is the big-endian encoding of `mflr r0` — the mode
          # name has to match the bytes or this decodes to garbage. Caught by
          # running it: the first version used `ppc64` and failed.
          ["/bin/bash", "-c", "cstool ppc64be '7c0802a6' | grep -qi mflr"],
          # CONTROL: an architecture that does not exist must FAIL. Without
          # this, every grep above could be matching an error message rather
          # than disassembly, and the whole test would prove nothing.
          ["/bin/bash", "-c", "! cstool no-such-arch 00 >/dev/null 2>&1"],
        ],
      } | Test,

    # The shared library is the reason to package this rather than let each
    # consumer vendor it. `BUILD_SHARED_LIBS` defaults to **OFF** upstream, so
    # a stock build produces libcapstone.a only — and anything linking that
    # absorbs capstone statically, making a capstone CVE invisible to pkgscan.
    # That default is one line in build.sh away from silently coming back.
    ships_shared_lib =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, pkgconf, coreutils],
        cmds = [
          ["/bin/bash", "-c", "test -e /usr/lib/libcapstone.so"],
          # A real versioned SONAME, not just the dev symlink.
          ["/bin/bash", "-c", "ls /usr/lib/libcapstone.so.* >/dev/null 2>&1"],
          # ...and no static archive, so nobody links it by accident.
          ["/bin/bash", "-c", "! test -e /usr/lib/libcapstone.a"],
          # pkg-config must resolve, or a downstream build quietly falls back
          # to its own vendored capstone.
          ["/bin/bash", "-c", "PKG_CONFIG_PATH=/usr/lib/pkgconfig pkg-config --exists capstone"],
        ],
      } | Test,

    # The security backports, checked on the installed library through the
    # public API, the way a consumer reaches them. build.sh already runs the
    # full reproducers under ASan at build time; this pins what an
    # uninstrumented libcapstone.so can show: M68K/RISCV insn names one past
    # the table are NULL (CVE-2026-49282), and no SH instruction from the
    # CVE-2026-55893 or GHSA-5q63-4654-94v6 reproducers reports more operands
    # than cs_sh.operands[] holds. The SH checks fail on stock 5.0.9 and on
    # 5.0.9 + e17ee44a alone (checked). The insn-name checks are a contract
    # check only: unpatched, the one-past read happened to return NULL on the
    # test host, so the ASan run in build.sh is what catches that regression.
    security_backports =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          set -e
          cat > t.c << 'EOF'
#include <stdio.h>
#include <capstone/capstone.h>
static int sh(cs_mode mode, const unsigned char *b, size_t n) {
    csh h; cs_insn *insn; int bad = 0;
    if (cs_open(CS_ARCH_SH, mode, &h) != CS_ERR_OK) return 1;
    cs_option(h, CS_OPT_DETAIL, CS_OPT_ON);
    insn = cs_malloc(h);
    const unsigned char *p = b; size_t rem = n; uint64_t a = 0x1000;
    while (rem && cs_disasm_iter(h, &p, &rem, &a, insn))
        if (insn->detail->sh.op_count > 3) {
            printf("sh insn %s %s: op_count %u\n", insn->mnemonic, insn->op_str, insn->detail->sh.op_count);
            bad = 1;
        }
    cs_free(insn, 1); cs_close(&h);
    return bad;
}
static int name_null(cs_arch arch, cs_mode mode, unsigned ending) {
    csh h;
    if (cs_open(arch, mode, &h) != CS_ERR_OK) return 1;
    const char *past = cs_insn_name(h, ending), *last = cs_insn_name(h, ending - 1);
    printf("insn_name(ENDING)=%s insn_name(ENDING-1)=%s\n", past ? past : "NULL", last ? last : "NULL");
    cs_close(&h);
    return past != NULL || last == NULL;
}
int main(void) {
    static const unsigned char ghsa_5q63[] = { 0x39, 0x99, 0xf5, 0x39 };
    static const unsigned char cve_55893[] = {
        0x1e,0xff,0x15,0x02,0x03,0x73,0x7e,0x77,0x00,0x8d,0x66,0x66,0x66,0x66,0xa0,0x99,
        0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x8d,0x71,0x35,0x8d,0x8d,0x49,0x3e,0xff,0x00,
        0x00,0x00,0x05,0x90,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,
        0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x78,0x8d,0x8d,0x8d,0x8d,
        0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x2f,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,0x8d,
        0xb9,0x4e };
    int r = 0;
    r |= name_null(CS_ARCH_M68K, CS_MODE_BIG_ENDIAN, M68K_INS_ENDING) << 0;
    r |= name_null(CS_ARCH_RISCV, CS_MODE_RISCV64, RISCV_INS_ENDING) << 1;
    r |= sh(CS_MODE_SH2A | CS_MODE_SHFPU | CS_MODE_BIG_ENDIAN, ghsa_5q63, sizeof ghsa_5q63) << 2;
    r |= sh(CS_MODE_SH2A | CS_MODE_SHFPU, cve_55893, sizeof cve_55893) << 3;
    if (r == 0) printf("OK\n");
    return r;
}
EOF
          gcc -Wall -Werror t.c -o t -lcapstone
          ./t | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
