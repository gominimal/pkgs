let { BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# Gate-0 — the make-or-break probe for the i386-then-cross pivot (R2 wall verdict, 2026-06-22).
# amd64-direct mes-tcc is upstream-unsolved (live-bootstrap #470); the proven route is the i386
# tcc/musl/gcc-mesboot spine, which requires the CS builder to RUN 32-bit (i386) static ELFs.
# This probe runs stage0-posix's 181-byte i386 hex0 seed (ELF 32-bit, Intel 80386, static, no
# section header) on its own x86 hex0-language source. If execve succeeds — i.e. the CS host
# kernel has CONFIG_IA32_EMULATION AND the build sandbox's seccomp/personality allows the i386
# syscall ABI (int 0x80 / 32-bit syscall numbers) — /build/out32 is produced and the build passes.
# ENOEXEC ("cannot execute binary file") or a seccomp kill = build fails = Gate-0 FAIL = the i386
# pivot is blocked (and we'd need a different builder kernel or the research-grade x86_64 mescc port).
{
  name = "ia32-probe",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # S3, reused
      extract = true,
    } | Source,
    coreutils, # /usr/bin/{chmod,mkdir,cp} (bare-path ops)
  ],
  cmds = [
    ["/usr/bin/chmod", "0755", "stage0-posix-1.9.1/bootstrap-seeds/POSIX/x86/hex0-seed"],
    # THE PROBE: execve the i386 (32-bit) hex0 seed, self-reproducing from its own source.
    # ENOEXEC / seccomp-kill HERE = no IA32 support = Gate-0 FAIL.
    ["stage0-posix-1.9.1/bootstrap-seeds/POSIX/x86/hex0-seed", "stage0-posix-1.9.1/x86/hex0_x86.hex0", "/build/out32"],
    ["/usr/bin/mkdir", "-p", "/build/output/usr/share/ia32-probe"],
    ["/usr/bin/cp", "/build/out32", "/build/output/usr/share/ia32-probe/out32"],
  ],
  outputs = {
    out32 = { glob = "usr/share/ia32-probe/out32" } | OutputData,
  },
} | BuildSpec
