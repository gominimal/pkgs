let { stack, .. } = import "minimal.ncl" in
# The reverse-engineering loadout: one session that takes an unknown binary from
# "what is this file" to "here is the C it decompiles to" to "here is what it
# does when it runs" —
#
#   file ./blob                          # identify
#   readelf -h ./blob                    # inspect (arch-agnostic, any e_machine)
#   analyzeHeadless /tmp proj -import ./blob \
#       -postScript Decompile.java       # DECOMPILE, scriptably
#   ghidraRun                            # ...or drive it by hand
#   gdb -q ./blob                        # break, step, inspect
#   gcore <pid>                          # dump a live process
#   strace -f ./blob                     # syscalls
#   diffoscope ./blob ./blob.patched     # what actually changed
#
# Opt-in by design: there is deliberately NO `matches_project_if_any`. Nothing
# about a source tree implies you want an RE bench — you ask for this one, the
# way you ask for the `aeneas` verification loadout.
#
# Everything here is OSI/FSF-open. Tools that would have been obvious additions
# were excluded on licence grounds and are named at the bottom so nobody
# re-proposes them.
stack {
  name = "reveng",

  build_packages = [
    # Build base. Present so you can compile a minimal repro or a test harness
    # against the thing you are reversing — half of RE is "does my theory about
    # this function actually reproduce".
    "gcc",
    "binutils",
    "make",
    "pkgconf",
    "linux_headers",

    # THE ANCHOR. Ghidra is the only credible open decompiler for native code,
    # and `analyzeHeadless` is what makes it a tool rather than a GUI toy — it
    # runs the same analysis over 400 binaries unattended.
    #
    # Shipped as the official prebuilt release (Apache-2.0): its Gradle build
    # fetches 67 URLs from seven hosts before compiling a line, so a hermetic
    # source build is not on the table. It carries no bundled JRE, so it runs
    # on the `jdk` below rather than smuggling in a second Java.
    #
    # On arm64 the five platform natives are built from source at package time,
    # because upstream publishes none for linux_arm_64 — without that Ghidra
    # imports and disassembles and then silently produces no C.
    "ghidra",
    "jdk",

    # The scriptable half. Ghidra answers "what does this function do"; rizin
    # answers "run that over 400 binaries and diff the results" — the shape
    # this distro's own tooling works in. Built against our system
    # zlib/zstd/xz/lz4/pcre2/openssl/tree-sitter rather than its seven vendored
    # copies, so a CVE in any of them is visible to pkgscan.
    "rizin",

    # The dynamic half, and the biggest hole in the distro before this loadout:
    # nothing could set a breakpoint or open a core dump. Built --with-python
    # (so gdb can host Python extensions) and --enable-targets=all (so it can
    # disassemble foreign architectures).
    "gdb",
    # gef turns gdb into the thing people actually want next to a decompiler:
    # context on every stop, heap inspection, pattern search. It is a gdb
    # EXTENSION, not a program — installed as its own launcher so `gef` is gdb
    # with gef loaded and `gdb` stays exactly what it was.
    "gef",

    # Already-shipping tools that are load-bearing in this workflow, listed
    # explicitly so the session is self-describing rather than inheriting them
    # from the base image: identify, inspect, trace, patch, diff.
    "file",
    "elfutils",
    "patchelf",
    "strace",
    "diffoscope",
    "hexyl",
    "python",
  ],

  build_env_vars = {
    # Ghidra's launcher searches a hardcoded list of distro JDK paths that does
    # not include our merged /usr tree, and fails with "Failed to find a
    # supported JDK" even when `java` is on PATH. Same value the `gradle` stack
    # uses.
    JAVA_HOME = "/usr/lib/jvm",

    # Read by Ghidra scripts and by PyGhidra (in-tree since 12.x, no extension
    # needed) to locate the install root.
    GHIDRA_INSTALL_DIR = "/usr/share/ghidra",
  },

  # An analysis bench has no canonical "build this directory" — the real use is
  # the pipeline in the header comment, driven by hand against a target binary.
  # Surface the anchor so a broken session fails loudly at start rather than
  # when you first reach for the decompiler.
  # Exercise all four anchors, so a session that cannot decompile, cannot
  # debug, cannot script or cannot load gef fails AT START rather than an hour
  # in. Each of these has a silent failure mode: analyzeHeadless exits 0 with
  # no decompiler, gdb builds fine without Python (and then gef cannot load),
  # and rizin builds fine having silently vendored seven libraries.
  build_cmd = "analyzeHeadless -help > /dev/null && rizin -v && gdb --version && gef -batch -ex 'gef help' > /dev/null",
}
#
# DELIBERATELY ABSENT, for the record:
#
#   volatility3  Volatility Software License — NOT OSI/FSF. Its copyleft is
#                broader than AGPL: "Additions" explicitly includes "software
#                designed to execute the software and parse its results, such
#                as a wrapper". Memory forensics has no open replacement;
#                MemProcFS was the fallback and bundles Elastic-License rules.
#   peda         CC-BY-NC-SA-3.0 (NonCommercial). Widely mislabelled "GPL".
#   nmap         NPSL, not plain GPL; §3 reaches software that merely executes
#                it and parses the results. A judgement call, not a slip.
#   frida        Genuinely open (wxWindows 3.1, OSI-approved) — everyone
#                assumes otherwise. Excluded on COST: all ten components are
#                git submodules with ~36 pinned forks including a Vala
#                compiler. Revisit when the rest of this is paying for itself.
