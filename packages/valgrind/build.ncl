let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let python = import "../python/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# ld.so symbols (the reason this package needs no glibc change)
# --------------------------------------------------------------
# Memcheck replaces strlen (amd64: also strcmp and memcmp) inside the dynamic
# linker from the first instruction, and finds those functions by name in
# ld.so's .symtab -- they are not exported, so .dynsym does not carry them.
# Distros that strip ld.so make every memcheck run abort with "Fatal error at
# startup: a function redirection which is mandatory for this platform-tool
# combination cannot be set up", and fix it with an ld.so debuginfo package
# or debuginfod. Neither is needed here: our glibc build does not strip
# (packages/glibc/build.sh), so /usr/lib/ld-linux-x86-64.so.2 and
# /usr/lib/ld-linux-aarch64.so.1 keep their full .symtab (and DWARF).
# Nothing in glibc promises that, so two things hold it in place:
#   * build.sh fails the build if the glibc in the sandbox (the same glibc this
#     package runs against: it is a runtime dep) has no .symtab entry for a
#     mandatory symbol;
#   * the memcheck tests below abort with that fatal error if it ever regresses.
# If glibc ever has to strip ld.so, the fix is a glibc output carrying the
# ld.so symbols that this package depends on -- not a debuginfod setting.
let version = "3.28.0" in
{
  name = "valgrind",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://sourceware.org/pub/valgrind/valgrind-%{version}.tar.bz2, verified
      # against its detached signature (valgrind-%{version}.tar.bz2.asc) from
      # Mark J. Wielaard, 28FF 4B30 A88D 5523 A7E2 CBA2 0376 A15C 6FFC 11CD, who
      # also signed 3.26.0 and 3.27.1.
      url = "gs://minimal-staging-archives/valgrind-%{version}.tar.bz2",
      sha256 = "9f7a18d128f05d3a80fea53e6953f34aad7200a425ceaee46099a8a798a7dd9c",
      extract = true,
      strip_prefix = "valgrind-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    # glibc dlopens libgcc_s.so.1 to unwind on pthread_cancel and aborts without it.
    # A dlopen is not DT_NEEDED, so missing-runtime_deps can't see it.
    subsetOf gcc-runtime ["libgcc"],
    glibc,
    # callgrind_annotate, callgrind_control, ms_print (build.sh points their
    # shebangs at /usr/bin/perl)
    perl,
    # cg_annotate, cg_diff, cg_merge (/usr/bin/python3)
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # ELF front ends: the launcher, the gdbserver relay, and the two network helpers.
    valgrind = { glob = "usr/bin/valgrind" } | OutputBin,
    vgdb = { glob = "usr/bin/vgdb" } | OutputBin,
    valgrind-di-server = { glob = "usr/bin/valgrind-di-server" } | OutputBin,
    valgrind-listener = { glob = "usr/bin/valgrind-listener" } | OutputBin,
    # Perl scripts.
    callgrind_annotate = { glob = "usr/bin/callgrind_annotate" } | OutputBin,
    callgrind_control = { glob = "usr/bin/callgrind_control" } | OutputBin,
    ms_print = { glob = "usr/bin/ms_print" } | OutputBin,
    # Python scripts.
    cg_annotate = { glob = "usr/bin/cg_annotate" } | OutputBin,
    cg_diff = { glob = "usr/bin/cg_diff" } | OutputBin,
    cg_merge = { glob = "usr/bin/cg_merge" } | OutputBin,

    # The tools themselves (memcheck-amd64-linux, callgrind-arm64-linux, ...):
    # static executables the launcher execs from VG_LIBDIR = /usr/libexec/valgrind.
    tools = { glob = "usr/libexec/valgrind/*-linux" } | OutputBin,
    # LD_PRELOADed into the client by each tool (malloc replacement, string
    # function intercepts).
    preloads = { glob = "usr/libexec/valgrind/vgpreload_*.so" } | OutputLib,
    # Suppressions, gdbserver target descriptions, the DHAT viewer, gdb's
    # valgrind-monitor python helpers.
    libexec_data = { glob = "usr/libexec/valgrind/*.{supp,xml,html,css,js,py}" } | OutputData,

    # Client-request headers (valgrind.h, callgrind.h: CALLGRIND_START_INSTRUMENTATION
    # etc.) and the static libraries for building out-of-tree tools.
    includes = { glob = "usr/include/valgrind/**" } | OutputData,
    static_libs = { glob = "usr/lib/valgrind/*.a" } | OutputLib,
    pkgconfig = { glob = "usr/lib/pkgconfig/valgrind.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "valgrind",
      # GPL-3.0-or-later overall; the client headers (valgrind.h, memcheck.h,
      # callgrind.h, ...) carry the bzip2-style licence; the bundled zstd
      # decoder in coregrind/m_debuginfo is BSD-3-Clause OR GPL-2.0-only.
      license_spdx = "GPL-3.0-or-later AND bzip2-1.0.6 AND (BSD-3-Clause OR GPL-2.0-only)",
    } | Attrs,

  # Every test builds its own program (rustc for the profiler ones: the fv-lab
  # use is instruction counts of rustc-built binaries). bash builtins only, so
  # the closure is bash-bootstrap + the compiler + valgrind's own runtime deps.
  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/usr/bin/bash", "-c", "v=$(/usr/bin/valgrind --version) && [ \"$v\" = 'valgrind-%{version}' ]"]],
      } | Test,

    # memcheck on a rustc-built binary: starts (the ld.so redirections are
    # mandatory, so a stripped ld.so fails here), produces the program's own
    # output, and reports no errors.
    memcheck_rust_clean =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, rust],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              /usr/bin/rustc -g -O -o hot - <<'EOF'
              #[inline(never)]
              fn collatz_steps(mut n: u64) -> u32 {
                  let mut s = 0;
                  while n != 1 { n = if n % 2 == 0 { n / 2 } else { 3 * n + 1 }; s += 1; }
                  s
              }
              fn main() {
                  let v: Vec<u64> = (1..20000).collect();
                  let total: u64 = v.iter().map(|&i| collatz_steps(i) as u64).sum();
                  println!("{}", total);
              }
              EOF
              want=$(./hot)
              got=$(/usr/bin/valgrind --tool=memcheck --error-exitcode=99 --leak-check=full -q ./hot)
              [ "$got" = "$want" ]
            "%
          ],
        ],
      } | Test,

    # The positive control: memcheck must actually instrument. A one-past-the-end
    # heap read in C has to be reported (exit 99) and named as an invalid read.
    memcheck_c_detects =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -uo pipefail
              gcc -g -O0 -x c - -o bad <<'EOF'
              #include <stdlib.h>
              #include <string.h>
              int main(void) {
                  char *p = malloc(8);
                  memset(p, 'a', 8);
                  volatile char c = p[8];
                  free(p);
                  return c == 'z';
              }
              EOF
              log=$(/usr/bin/valgrind --tool=memcheck --error-exitcode=99 ./bad 2>&1)
              rc=$?
              [ "$rc" = 99 ] && [[ $log == *"Invalid read of size 1"* ]]
            "%
          ],
        ],
      } | Test,

    # Callgrind instruction counts on a rustc-built binary, annotated per
    # function by callgrind_annotate (perl).
    callgrind_rust_annotate =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, rust],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              /usr/bin/rustc -g -O -o hot - <<'EOF'
              #[inline(never)]
              fn collatz_steps(mut n: u64) -> u32 {
                  let mut s = 0;
                  while n != 1 { n = if n % 2 == 0 { n / 2 } else { 3 * n + 1 }; s += 1; }
                  s
              }
              fn main() {
                  let total: u64 = (1..20000u64).map(|i| collatz_steps(i) as u64).sum();
                  println!("{}", total);
              }
              EOF
              /usr/bin/valgrind --tool=callgrind --callgrind-out-file=cg.out ./hot >/dev/null
              ann=$(/usr/bin/callgrind_annotate cg.out)
              [[ $ann == *"PROGRAM TOTALS"* ]] && [[ $ann == *"collatz_steps"* ]]
            "%
          ],
        ],
      } | Test,

    # Cachegrind instruction counts, annotated by cg_annotate (python).
    cachegrind_rust_annotate =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, rust],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              /usr/bin/rustc -g -O -o hot - <<'EOF'
              #[inline(never)]
              fn collatz_steps(mut n: u64) -> u32 {
                  let mut s = 0;
                  while n != 1 { n = if n % 2 == 0 { n / 2 } else { 3 * n + 1 }; s += 1; }
                  s
              }
              fn main() {
                  let total: u64 = (1..20000u64).map(|i| collatz_steps(i) as u64).sum();
                  println!("{}", total);
              }
              EOF
              /usr/bin/valgrind --tool=cachegrind --cachegrind-out-file=cg.out ./hot >/dev/null
              ann=$(/usr/bin/cg_annotate cg.out)
              [[ $ann == *"collatz_steps"* ]]
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
