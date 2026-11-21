let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let bison = import "../bison/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let capstone = import "../capstone/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let inetutils = import "../inetutils/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let tar = import "../tar/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

# perf ships in the kernel tree (tools/perf). perf follows the 6.12 LTS line,
# and its tarball comes from the same mirror bucket as virtio-linux's (each
# package pins its own version). perf talks to the running kernel through the
# stable perf_event_open ABI, so it need not match the host kernel.
let version = "6.12.118" in

# Run one perf command that needs perf_event_open. Where the kernel allows it
# the command must succeed and `check` must pass on its output. Two
# environments are accepted, each only on perf's own diagnosis of it:
#  * the kernel refuses the syscall (EACCES/EPERM from perf_event_paranoid or
#    a seccomp filter, ENOSYS where it is absent);
#  * no sysfs (the minimal test sandbox): perf cannot read the CPU list, so
#    `perf record` maps no ring buffers and writes a file with no samples.
#    Counting (`perf stat`) still works there.
# A signal (exit 130-192) is a crash and always fails. Exit 129 is perf's
# usage error (a wrong option), reported as such.
let perf_event_test = fun name cmd check =>
  {
    class = 'Standalone,
    test_deps = [base],
    cmds = [
      [
        "/usr/bin/bash",
        "-c",
        m%"
          set -u
          cd "$(mktemp -d)"
          rc=0
          out=$(%{cmd} 2>&1) || rc=$?
          printf '%s\n' "$out"
          if [ "$rc" -eq 129 ]; then
            echo "%{name}: perf rejected the command line (usage error, rc=129)" >&2
            exit 1
          elif [ "$rc" -gt 129 ] && [ "$rc" -le 192 ]; then
            echo "%{name}: perf died with signal $((rc - 128))" >&2
            exit 1
          elif grep -Eq 'perf_event_paranoid|sys_perf_event_open\(\) syscall returned with|No permission to enable' <<<"$out"; then
            echo "%{name}: perf ran; the kernel refused perf_event_open (rc=$rc)"
          elif ! [ -r /sys/devices/system/cpu/online ] && grep -q 'data has no samples' <<<"$out"; then
            # `perf report` exits 0 here, so this is checked before success
            echo "%{name}: perf ran; no sysfs here, so perf record captured no samples (rc=$rc)"
          elif [ "$rc" -eq 0 ]; then
            %{check} || { echo "%{name}: perf ran but its output failed the check" >&2; exit 1; }
            echo "%{name}: perf_event_open allowed, check passed"
          else
            echo "%{name}: perf failed (rc=$rc) without a perf_event_open refusal" >&2
            exit 1
          fi
        "%
      ],
    ],
  } | Test
in
{
  name = "perf",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "08308460320e852ac0745b2be3c7ae1cd81bdad713506ed7d817ba1ec9e1a5a5",
      extract = true,
      strip_prefix = "linux-%{version}",
    } | Source,
    base,
    bison,
    flex,
    m4, # bison runs m4
    make,
    pkgconf,
    # build-time only: generates the vendor PMU event tables (jevents)
    python,
    toolchain,
  ],
  runtime_deps = [
    # perf-archive / perf-iostat are bash scripts
    bash,
    # perf-archive (libexec/perf-core) runs, in 6.12.118: tar cjf / tar xvf
    # (tar + bzip2), grep, find, and coreutils' cut, tr, wc, comm, ls, mktemp,
    # readlink, rm and date; `perf archive --all` also runs hostname, which
    # only inetutils ships. The archive_tools test checks them without base.
    bzip2,
    coreutils,
    findutils,
    grep,
    inetutils,
    tar,
    capstone,
    elfutils,
    glibc,
    xz,
    zlib,
    zstd,
    # libstdc++ for C++ demangling (__cxa_demangle); elfutils already
    # carries the same subset at runtime, so this adds nothing to the closure.
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    perf = { glob = "usr/bin/perf" } | OutputBin,
    perf_core = { glob = "usr/libexec/perf-core/perf-{archive,iostat}" } | OutputBin,
    tips = { glob = "usr/share/doc/perf-tip/tips.txt" } | OutputData,
    bash_completion = { glob = "etc/bash_completion.d/perf" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      # No source_provenance, as with virtio-linux: torvalds/linux would tie
      # perf to every kernel CVE, nearly all of which are in code perf does
      # not contain.
    } | Attrs,

  tests = {
    cli =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -u
              fail() { echo "FAIL: $*" >&2; exit 1; }
              # Each step names itself and what perf said, so a failure is legible.
              out=$(perf version 2>&1) || fail "perf version (rc=$?): $out"
              echo "$out"
              [ "$out" = "perf version %{version}" ] || fail "unexpected version"
              out=$(perf --help 2>&1) || fail "perf --help (rc=$?): $out"
              grep -q 'record' <<<"$out" || fail "perf --help lists no commands: $out"
              # -h prints the option summary and exits 129, without a man pager
              out=$(perf stat -h 2>&1)
              grep -q 'Usage: perf stat' <<<"$out" || fail "perf stat -h: $out"
              out=$(perf list sw 2>&1) || fail "perf list sw (rc=$?): $out"
              # Software events (task-clock, ...) are read from
              # /sys/bus/event_source; build-bot's test sandbox has no /sys and
              # lists only perf's own tool events (duration_time, ...).
              grep -Eq 'task-clock|duration_time' <<<"$out" || fail "perf list sw: $out"
              out=$(perf version --build-options 2>&1) || fail "build-options: $out"
              grep -Eq 'libcapstone: \[ on' <<<"$out" || fail "capstone missing: $out"
              echo "cli: ok"
            "%
          ],
        ],
      } | Test,
    # perf's own in-process self-tests that need no perf_event_open: libdw
    # DWARF unwinding of a captured stack, libelf symbol loading, the
    # demanglers and sample (de)serialisation.
    selftest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -u
              suites=('Test dwarf unwind' 'Symbols' 'Demangle Java' 'Demangle OCaml' 'Sample parsing')
              out=$(perf test "${suites[@]}" 2>&1)
              printf '%s\n' "$out"
              # A name can match more than one suite (amd64 adds "x86 Sample
              # parsing"), so each name needs its own Ok line, and nothing may
              # fail or skip.
              for s in "${suites[@]}"; do
                grep -F -- "$s" <<<"$out" | grep -q ': Ok$' || { echo "selftest: no Ok line for '$s'" >&2; exit 1; }
              done
              ! grep -Eq 'FAILED|Skip' <<<"$out" || { echo "selftest: a suite failed or skipped" >&2; exit 1; }
            "%
          ],
        ],
      } | Test,
    # perf-archive's tools come from perf's own closure: no base here, so a
    # missing runtime dep is command-not-found.
    archive_tools =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%"
              set -u
              for t in tar bzip2 grep find cut tr wc comm ls mktemp readlink rm date hostname; do
                command -v "$t" >/dev/null || { echo "archive_tools: $t is not in perf's closure" >&2; exit 1; }
              done
              cd "$(mktemp -d)"
              echo x > f
              tar cjf f.tar.bz2 f && tar tjf f.tar.bz2 | grep -qx f || { echo "archive_tools: tar cjf round trip failed" >&2; exit 1; }
              [ -x /usr/libexec/perf-core/perf-archive ] || { echo "archive_tools: perf-archive not shipped" >&2; exit 1; }
              echo "archive_tools: ok"
            "%
          ],
        ],
      } | Test,
    stat = perf_event_test "stat" "perf stat -x, -e task-clock -- true" "grep -q task-clock <<<\"$out\"",
    record_report =
      perf_event_test
        "record_report"
        "perf record -e task-clock -o perf.data -- bash -c 'i=0; while [ $i -lt 300000 ]; do i=$((i+1)); done' && perf report -i perf.data --stdio --sort comm,dso && perf annotate -i perf.data --stdio"
        "grep -q '^ *[0-9.]*% *bash' <<<\"$out\" && grep -q 'Percent' <<<\"$out\"",
  },
} | BuildSpec
