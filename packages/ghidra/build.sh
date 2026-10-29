#!/bin/sh
set -eux

# The asset is `ghidra_<version>_PUBLIC_<builddate>.zip` and extracts to
# `ghidra_<version>_PUBLIC/`. The build date is globbed rather than pinned as a
# second build_arg on purpose: pkgmgr's updater rewrites the `version` binding
# and the first sha256, so a separate date pin would silently go stale on every
# bump — a near-miss pin that looks maintained is worse than no pin.
python3 -m zipfile -e ghidra_${MINIMAL_ARG_VERSION}_PUBLIC_*.zip .

SRC="$(pwd)/ghidra_${MINIMAL_ARG_VERSION}_PUBLIC"
GHIDRA_TREE="$OUTPUT_DIR/usr/share/ghidra"

mkdir -p $OUTPUT_DIR/usr/{bin,share/ghidra}
cp -r "$SRC"/* "$GHIDRA_TREE/"

# Drop the GhidraClass training material. It is 16 deliberately-crafted ELF
# executables and shared objects used for teaching RE — nothing execs them, and
# shipping unowned binaries inside a data output is exactly what the
# output-types checker is there to catch. (They are also invisible to pkgscan,
# which is a poor property for binaries we ship.)
rm -rf "$GHIDRA_TREE/docs/GhidraClass"

# Drop the Windows and macOS natives. This is a Linux package; they are dead
# weight, and declaring them as executables makes the output checker try to
# parse PE/Mach-O as ELF. Keeping only os/linux_* also makes the ARCH GAP
# legible instead of hidden behind three other platforms.
find "$GHIDRA_TREE" -type d -name "win_*" -prune -exec rm -rf {} +
find "$GHIDRA_TREE" -type d -name "mac_*" -prune -exec rm -rf {} +

# Host architecture, resolved ONCE and early because later sections branch on
# it. It once sat below a block that read it, so $HOST_OSDIR was empty there
# and that arm64 arm silently never ran — the build
# still succeeded and simply produced a package missing the thing it had just
# been taught to add. `set -u` above now makes that class of mistake fatal
# instead of quiet.
case "$(uname -m)" in
    aarch64 | arm64) HOST_OSDIR=linux_arm_64 ;;
    x86_64) HOST_OSDIR=linux_x86_64 ;;
    *)
        echo "unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# 7-Zip: no JNI natives since 12.2.
# ---------------------------------------------------------------------------
#
# Ghidra 12.2 removed sevenzipjbinding (GP-7095): zip, 7z, bzip2 and xz now go
# through Apache commons-compress in pure Java, so the arm64 parity gap this
# recipe used to close with a pinned aarch64 sevenzipjbinding native is gone,
# and that pin (a second Source) is gone with it. If a future Ghidra brings the
# JNI library back, it would again ship x86-only natives and silently degrade
# arm64; fail here so that bump restores the arm64 handling first (see this
# recipe's git history for 12.1.x, which carried it).
if find "$GHIDRA_TREE" \( -name 'sevenzipjbinding*.jar' -o -name 'lib7-Zip-JBinding.so' -o -type d -name sevenzipnativelibs \) | grep -q .; then
    echo "ghidra ships sevenzipjbinding again; restore the arm64 7-Zip native handling" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Platform natives
# ---------------------------------------------------------------------------
#
# Upstream's release matrix publishes natives for linux_x86_64, mac_arm_64,
# mac_x86_64 and win_x86_64 — and NOT linux_arm_64. That is a build-farm gap,
# not a portability gap: every one of these components already declares
# `targetPlatform "linux_arm_64"` in its own Gradle native model, and the
# mac_arm_64 binaries in this same zip are built from the identical sources.
#
# The consequence on an arm64 host is not a warning, it is a silently degraded
# run. Application.getModuleOSFile() implements an x86_64 fallback ONLY for
# WIN_ARM_64 (Windows emulation) and MAC_ARM_64 (Rosetta 2) — there is
# deliberately no LINUX_ARM_64 arm. So `decompile` is simply not found;
# DecompileProcessFactory logs one error behind a static latch, openProgram()
# returns false, and the five callers that ignore that boolean (CppExporter,
# DecompilerParameterIdCmd, DecompilerCallback, ObjcMessageAnalyzer,
# FormatStringAnalyzer) carry on. analyzeHeadless then exits 0 having produced
# no decompiled C.
#
# We close the gap by building the natives from the C/C++ sources that the
# release zip ALREADY SHIPS — `src/decompile/**`, `GPL/DemanglerGnu/src/**`
# and `src/lzfse/**` are included in the distribution on purpose (see the
# `assembleDistribution { from(projectDir) { include "src/decompile/**" } }`
# blocks upstream) and are byte-identical to the git tag. No second Source, no
# second sha256 for the updater to leave stale, no network.


# The three modules that carry `os/<platform>` natives. Everything else under
# os/ is a README or a Windows-only tool (PDB/pdb.exe, GPL/DMG llio DLLs).
NATIVE_MODULES="Ghidra/Features/Decompiler GPL/DemanglerGnu Ghidra/Features/FileFormats"

if [ -f "$GHIDRA_TREE/Ghidra/Features/Decompiler/os/$HOST_OSDIR/decompile" ]; then
    # Upstream started publishing this platform. Say so out loud rather than
    # letting the build step quietly become a no-op — a silent skip here is
    # indistinguishable from a silent failure.
    echo "upstream ships $HOST_OSDIR natives; skipping the local native build"
else
    echo "upstream ships no $HOST_OSDIR natives; building them from the source in the release zip"

    # --- decompile + sleigh -------------------------------------------------
    #
    # Built via the Makefile upstream ships alongside the sources (Gradle is
    # NOT required and would want the network). Three overrides, each needed:
    #
    #  ARCH_TYPE=   The whole arm64 fix. The Makefile's arch detection is
    #               `ifeq ($(ARCH),x86_64) -m64 else -m32` and carries an
    #               in-tree "# TODO: need to revise to support arm64/aarch64",
    #               so aarch64 falls into the -m32 branch, which aarch64 g++
    #               does not implement. Note `make ARCH=aarch64` does NOT help
    #               — every non-x86_64 value takes the else. ARCH_TYPE is a
    #               plain `=` with no `override`, so the command line wins.
    #               (OSDIR does NOT need overriding: it is read only by the
    #               install_ghidra* targets, which copy into $(GHIDRA_BIN) =
    #               ../../../../../../../ghidra.bin, a sibling dev checkout we
    #               do not have. We install the artifacts ourselves below.)
    #
    #  YACC/LEX     Tripwires, not decoration — see the `touch` note below.
    #
    #  ADDITIONAL_FLAGS / MAKE_STATIC
    #               The two slots the Makefile threads into every recipe:
    #               ADDITIONAL_FLAGS lands on compile AND link, MAKE_STATIC on
    #               link only. Determinism flags per pkgs AGENTS.md.
    cd "$SRC/Ghidra/Features/Decompiler/src/decompile/cpp"

    # `python3 -m zipfile` restores no mtimes, so extracted files inherit
    # ARCHIVE ORDER — and slghparse.y sits ~130 entries AFTER slghparse.cc.
    # Make therefore believes the checked-in parser is stale and reaches for
    # bison, then (via the recipe-less `slghparse.hh: slghparse.y slghparse.cc`
    # rule cascading into slghscan.cc) for $(LEX), which the Makefile never
    # assigns — so it falls back to make's builtin `lex`, not even flex.
    # Neither exists in this sandbox and there is no network to fetch them.
    # Re-stamp the committed generated parsers so no .y/.l is newer than its
    # own output. The `[ -f ]` guard matters: a bare `touch` on a file upstream
    # removed would CREATE an empty stub and break the compile confusingly.
    for f in grammar.cc grammar.hh xml.cc xml.hh pcodeparse.cc pcodeparse.hh \
        slghparse.cc slghparse.hh slghscan.cc; do
        [ -f "$f" ]
        touch "$f"
    done

    # Two SEPARATE invocations on purpose. The Makefile selects its dependency
    # file with a ladder of exact `ifeq ($(MAKECMDGOALS),<goal>)` tests; with
    # two goals MAKECMDGOALS is the string "ghidra_opt sleigh_opt", matches
    # none of them, and DEPNAMES falls back to `com_dbg/depend com_opt/depend`
    # — the console-mode set, which drags in loadimage_bfd.cc (<bfd.h>) and
    # rulecompile.cc (ruleparse.hh, whose .y has no checked-in output). A bare
    # `make` with no goal lands in the same fallback.
    MAKE_OVERRIDES="ARCH_TYPE= YACC=false LEX=false"
    MAKE_REPRO="ADDITIONAL_FLAGS=-ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

    # shellcheck disable=SC2086
    make -j"$(nproc)" $MAKE_OVERRIDES \
        "$MAKE_REPRO" MAKE_STATIC="-Wl,--build-id=none" ghidra_opt

    # `sleigh` is NOT resolved by anything at runtime — there is no
    # getOSFile("sleigh") anywhere in the shipped Java, support/sleigh launches
    # the pure-Java ghidra.pcodeCPort.slgh_compile.SleighCompileLauncher, and
    # 135 prebuilt .sla files ship in the zip. We build it anyway for parity
    # with every platform upstream publishes, so nobody has to re-derive this
    # question from a half-populated os/linux_arm_64. It is the only target
    # that needs zlib (-lz via $(LNK)); if it ever becomes a maintenance
    # problem, deleting this one invocation plus the zlib deps is safe.
    # shellcheck disable=SC2086
    make -j"$(nproc)" $MAKE_OVERRIDES \
        "$MAKE_REPRO" MAKE_STATIC="-Wl,--build-id=none" sleigh_opt

    # Upstream's own rename (install_ghidraopt does `cp ghidra_opt ... decompile`).
    install -Dm755 ghidra_opt \
        "$GHIDRA_TREE/Ghidra/Features/Decompiler/os/$HOST_OSDIR/decompile"
    install -Dm755 sleigh_opt \
        "$GHIDRA_TREE/Ghidra/Features/Decompiler/os/$HOST_OSDIR/sleigh"

    # --- demangler_gnu_v2_24 / v2_41 ---------------------------------------
    #
    # REQUIRED, not optional: GnuDemangler.demangle() goes straight to
    # GnuDemanglerNativeProcess with no pure-Java fallback, and the default
    # analyzer setting is GNU_DEMANGLER_V2_41 — so without these, every C++
    # binary loses symbol demangling.
    #
    # These have no Makefile; they are plain C built by a Gradle native model.
    # The flags below are transcribed from GPL/DemanglerGnu/build.gradle, which
    # (unlike the other two buildNatives.gradle files) IS shipped in the zip —
    # so this recipe stays checkable against the source we build from. The
    # -DMAIN_CPLUS_DEM asymmetry is load-bearing: v2_24's main() lives inside
    # `#ifdef MAIN_CPLUS_DEM` in cplus-dem.c, while v2_41 gets its main from
    # cxxfilt.c and must NOT have the define.
    for v in 24 41; do
        case "$v" in
            24) DEMANGLER_MAIN="-DMAIN_CPLUS_DEM" ;;
            *) DEMANGLER_MAIN="" ;;
        esac
        cd "$SRC/GPL/DemanglerGnu/src/demangler_gnu_v2_$v"
        # shellcheck disable=SC2086
        gcc -std=gnu17 $DEMANGLER_MAIN -DHAVE_STDLIB_H -DHAVE_STRING_H \
            -ffile-prefix-map="$(pwd)=/builddir" -gno-record-gcc-switches \
            -Wl,--build-id=none \
            -I headers c/*.c -o "demangler_gnu_v2_$v"
        install -Dm755 "demangler_gnu_v2_$v" \
            "$GHIDRA_TREE/GPL/DemanglerGnu/os/$HOST_OSDIR/demangler_gnu_v2_$v"
    done

    # --- lzfse --------------------------------------------------------------
    #
    # Optional (Apple-compressed filesystems only), but it is eight C files and
    # building it is what lets us drop os/linux_x86_64 wholesale below.
    #
    # Flags from Ghidra/Features/FileFormats/buildNatives.gradle at tag
    # Ghidra_<version>_build. That file is NOT in the release zip, so unlike
    # the demangler above this recipe is transcribed and must be re-checked
    # against the tag if the lzfse build ever misbehaves. `c/*.c` currently
    # resolves to exactly the eight files upstream lists by name.
    #
    # -D__arm64__ is a real correctness fix, not a hack: lzfse gates its 64-bit
    # FSE bitstream and its int64 lzfse_offset/lzvn_offset on
    # `defined(_M_AMD64) || defined(__x86_64__) || defined(__arm64__)`, and
    # __arm64__ is an APPLE-only predefined macro — Linux aarch64 compilers
    # define only __aarch64__. Without it we would silently get the 32-bit
    # path (slower, and int32 buffer offsets) on the one platform upstream has
    # never built.
    case "$HOST_OSDIR" in
        linux_arm_64) LZFSE_ARCH_DEFINE="-D__arm64__" ;;
        *) LZFSE_ARCH_DEFINE="" ;;
    esac
    cd "$SRC/Ghidra/Features/FileFormats/src/lzfse/c"
    # shellcheck disable=SC2086
    gcc -std=c99 -Wall -O2 -DLINUX -D_LINUX $LZFSE_ARCH_DEFINE \
        -ffile-prefix-map="$(pwd)=/builddir" -gno-record-gcc-switches \
        -Wl,--build-id=none \
        ./*.c -o lzfse
    install -Dm755 lzfse \
        "$GHIDRA_TREE/Ghidra/Features/FileFormats/os/$HOST_OSDIR/lzfse"

    cd "$SRC/.."
fi

# Now that os/$HOST_OSDIR is populated for every native module, drop the
# foreign-arch Linux natives. Before this, an arm64 package shipped 4.8 MB of
# x86_64 ELF that can never execute here (and, sitting inside an OutputData
# glob with allow_executable, that the output-types checker explicitly
# no-ops rather than arch-checks). Restricted to the three native modules on
# purpose, so the extension-skeleton READMEs under Extensions/.../os/ survive.
for m in $NATIVE_MODULES; do
    for d in "$GHIDRA_TREE/$m"/os/linux_*; do
        [ -d "$d" ] || continue
        [ "$(basename "$d")" = "$HOST_OSDIR" ] || rm -rf "$d"
    done
done

# `python3 -m zipfile` does not preserve the executable bit, so every launcher
# and every prebuilt native arrives non-executable. Restore them explicitly
# rather than blanket-chmod'ing the tree.
#
# The per-module loop replaces an earlier `Ghidra/Features/*/os` glob that
# never reached GPL/DemanglerGnu — which is why the two GNU demanglers have
# been shipping mode 0644 (Ghidra execs them by absolute path via
# Runtime.exec, so that was a live, silent breakage on x86_64 too). It also
# stops chmod'ing GhidraServer/os/readme.txt.
# ...and a hand-maintained list has now been wrong TWICE: first the two GNU
# demanglers (see above), and still today 27 shell scripts — every one of the
# debugger-launcher `.sh` files and all of `server/` — because `support/*` is a
# SHALLOW glob. Verified in a built tree: 27 `.sh` files without the exec bit
# against 1 with it.
#
# So stop maintaining a list. Restore the bit on exactly the files UPSTREAM
# marked executable, read from the zip's own mode metadata, skipping anything
# we deliberately deleted. This tracks upstream's intent across every future
# release instead of drifting from it.
python3 - ghidra_${MINIMAL_ARG_VERSION}_PUBLIC_*.zip "$GHIDRA_TREE" <<'PY'
import os, sys, zipfile

zpath, tree = sys.argv[1], sys.argv[2]
restored = skipped = 0
with zipfile.ZipFile(zpath) as z:
    for info in z.infolist():
        if info.is_dir():
            continue
        # Strip the leading `ghidra_<version>_PUBLIC/` component.
        rel = info.filename.split("/", 1)
        if len(rel) != 2:
            continue
        if not (info.external_attr >> 16) & 0o111:
            continue
        path = os.path.join(tree, rel[1])
        if not os.path.exists(path):
            skipped += 1      # win_*/mac_*/GhidraClass — deleted above
            continue
        os.chmod(path, os.stat(path).st_mode | 0o111)
        restored += 1
print("exec bit restored on %d files (%d deliberately-deleted skipped)"
      % (restored, skipped))
PY

# The natives we BUILT are not in the zip, so they need it explicitly.
for m in $NATIVE_MODULES; do
    [ -d "$GHIDRA_TREE/$m/os/$HOST_OSDIR" ] || continue
    find "$GHIDRA_TREE/$m/os/$HOST_OSDIR" -type f -exec chmod +x {} \;
done

# `analyzeHeadless` is the whole reason this is packaged — the GUI is a bonus.
# Both launchers resolve the install root from their own path, so a symlink
# would break them; wrap instead.
#
# JAVA_HOME is set here rather than left to the session because Ghidra's
# launcher searches a hardcoded list of distro JDK paths that does not include
# our merged /usr tree, and fails with "Failed to find a supported JDK" even
# though `java` is on PATH.
for launcher in analyzeHeadless ghidraRun pyghidraRun; do
    [ -f "$GHIDRA_TREE/support/$launcher" ] ||
        [ -f "$GHIDRA_TREE/$launcher" ] || continue
    cat > $OUTPUT_DIR/usr/bin/$launcher << EOF
#!/bin/sh
export JAVA_HOME=\${JAVA_HOME:-/usr/lib/jvm}
export GHIDRA_INSTALL_DIR=/usr/share/ghidra
if [ -x "/usr/share/ghidra/support/$launcher" ]; then
    exec /usr/share/ghidra/support/$launcher "\$@"
fi
exec /usr/share/ghidra/$launcher "\$@"
EOF
    chmod +x $OUTPUT_DIR/usr/bin/$launcher
done
