#!/bin/bash
set -euo pipefail

# The kernel tarball is extracted with strip_prefix, so we start at the tree
# root; perf lives in tools/perf and is built with its own Makefile.
#
# min's build and test sandboxes mount no /sys. perf reads software events
# and PMUs from /sys/bus/event_source, so there `perf list sw` shows only its
# tool events and `perf record` writes no samples (see the tests in build.ncl).

# Reproducibility (pkgs AGENTS.md). perf's Makefile.config builds CFLAGS from
# EXTRA_CFLAGS and appends to LDFLAGS from the environment.
# The same per-arch baseline as the sibling packages (bash, elfutils, zstd).
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
EXTRA_CFLAGS="$MARCH -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="-Wl,--build-id=none"

# Every optional feature is named explicitly, so the result never depends on
# what happens to be visible in the build environment. perf's feature probes
# silently drop a library they cannot find, so the wanted ones are also
# asserted after the build (below).
#
# ON  (all already in elfutils' runtime closure, plus capstone; perf >= 6.7
#      reads capabilities with capget(2) itself, so libcap is not used):
#   libelf + libdw    symbol resolution, DWARF line info, --call-graph=dwarf
#                     unwinding (libdw-dwarf-unwind)
#   zlib/lzma/zstd    compressed .ko / debuginfo and `perf record -z`
#   capstone          `perf annotate` disassembles in-process, no objdump
#   cxa-demangle      C++ symbol demangling (libstdc++, already pulled in by
#                     elfutils)
#   jevents           vendor PMU event names + metrics in `perf list` /
#                     `perf stat -M` (python3 at build time only)
# OFF:
#   libtraceevent     not packaged; drops perf trace/sched/kmem/lock/kwork
#                     and tracepoint pretty-printing
#   libbpf/BPF skel   needs clang + bpftool; drops --bpf-counters, off-cpu
#   python/perl       scripting (`perf script -s`)
#   slang/gtk2        TUI/GUI report browsers (`perf report` uses --stdio)
#   libunwind         libdw already provides DWARF unwinding
#   libbfd/libllvm    capstone covers annotate; libbfd is a GPL-3 link
#   numa, babeltrace, libcrypto, libpfm4, libaudit, debuginfod, jvmti, SDT,
#   vdso32/x32 helpers (need multilib)
PERF_MAKE_ARGS=(
  prefix=/usr
  CC=gcc
  HOSTCC=gcc
  PYTHON=python3
  WERROR=0
  DEBUG=0
  NO_LIBTRACEEVENT=1
  NO_LIBBPF=1
  BUILD_BPF_SKEL=0
  NO_LIBPYTHON=1
  NO_LIBPERL=1
  NO_SLANG=1
  NO_GTK2=1
  NO_LIBUNWIND=1
  NO_LIBLLVM=1
  NO_LIBNUMA=1
  NO_LIBBABELTRACE=1
  NO_LIBCRYPTO=1
  NO_LIBPFM4=1
  NO_LIBAUDIT=1
  NO_LIBDEBUGINFOD=1
  NO_JVMTI=1
  NO_SDT=1
  NO_PERF_READ_VDSO32=1
  NO_PERF_READ_VDSOX32=1
  NO_SHELLCHECK=1
  EXTRA_CFLAGS="$EXTRA_CFLAGS"
)

make -C tools/perf -j"$(nproc)" "${PERF_MAKE_ARGS[@]}"

# Fail closed on the feature set: a probe that quietly failed must not ship a
# perf without DWARF unwinding or capstone, and nothing we turned off may have
# come back.
perf_bin=tools/perf/perf
build_options=$("$perf_bin" version --build-options)
echo "$build_options"
# Lines look like `   libelf: [ on  ]  # HAVE_LIBELF_SUPPORT`. A name that
# is not listed reads as "", so a typo here fails instead of passing.
feature_state() { awk -v f="$1:" '$1 == f { print $3 }' <<<"$build_options"; }
for f in libelf dwarf dwarf_getlocations dwarf-unwind libcapstone zlib lzma zstd syscall_table auxtrace; do
  [ "$(feature_state "$f")" = on ] || { echo "perf: wanted feature '$f' is not built in" >&2; exit 1; }
done
for f in libtraceevent bpf bpf_skeletons libpython libperl libslang libunwind libbfd libcrypto libnuma libaudit libpfm4 debuginfod; do
  [ "$(feature_state "$f")" = OFF ] || { echo "perf: feature '$f' should be OFF" >&2; exit 1; }
done
# The link set is part of the deliberate feature set too: every DT_NEEDED
# must be one runtime_deps provides, and the ones we chose must be there.
needed=$(readelf -d "$perf_bin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
echo "perf NEEDED:" $needed
for lib in $needed; do
  case "$lib" in
    libc.so.6 | libm.so.6 | ld-linux-*.so.* | libgcc_s.so.1 | libstdc++.so.6 | \
      libelf.so.1 | libdw.so.1 | libz.so.1 | liblzma.so.5 | libzstd.so.1 | libcapstone.so.5) ;;
    *) echo "perf: unexpected DT_NEEDED $lib" >&2; exit 1 ;;
  esac
done
for lib in libdw.so.1 libstdc++.so.6 libcapstone.so.5 libzstd.so.1; do
  grep -qx "$lib" <<<"$needed" || { echo "perf: expected to link $lib" >&2; exit 1; }
done

make -C tools/perf "${PERF_MAKE_ARGS[@]}" DESTDIR="$OUTPUT_DIR" install-tools

# install-tools always adds a `trace` link, but `perf trace` needs
# libtraceevent and is not built. Also drop the dlfilter example/test objects
# and their header, which nothing at runtime needs.
rm -f "$OUTPUT_DIR/usr/bin/trace"
rm -rf "$OUTPUT_DIR/usr/libexec/perf-core/dlfilters" "$OUTPUT_DIR/usr/include"
