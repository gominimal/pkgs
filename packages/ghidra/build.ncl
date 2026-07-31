let { subsetOf, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let make = import "../make/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "12.1.2" in
{
  name = "ghidra",
  build_deps = [
    { file = "build.sh" } | Local,
    # THE OFFICIAL PREBUILT RELEASE, not a source build — a deliberate choice.
    #
    # Ghidra's Gradle build runs `gradle/support/fetchDependencies.gradle`
    # BEFORE a line compiles: 67 URLs across seven hosts, including binary
    # artifacts with no source (AXMLPrinter2.jar from the dead Google Code
    # archive, per-platform Z3 zips, yajsw from SourceForge), a full
    # postgresql tarball and PyPI wheels — and only then does Maven Central
    # resolution start. It also requires JDK 25 to BUILD; we ship 21.
    #
    # The release zip is the same tradeoff the `jdk` package already accepts,
    # and it ships NO bundled JRE (`jre/` and `bin/java` are both absent), so
    # Ghidra runs on our jdk rather than smuggling in a second Java.
    #
    # THIS IS ALSO THE SOURCE FOR THE PLATFORM NATIVES. There is deliberately
    # no second Source: `assembleDistribution` pulls `src/decompile/**`,
    # `GPL/DemanglerGnu/src/**` and `src/lzfse/**` into the release zip, and
    # those 310 files are byte-identical to the corresponding git tag. Adding
    # the GitHub tag tarball would mean 76 MiB of extra download and a 313 MiB
    # extraction to obtain files we already have — and, worse, a SECOND sha256
    # in this file. pkgmgr's updater replaces only the FIRST one, so the
    # second would point at the new tag with the old hash on the next bump.
    #
    # SHA-256 is the one published in the release body, not one we computed:
    # https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_%{version}_build
    {
      url = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_%{version}_build/ghidra_%{version}_PUBLIC_20260605.zip",
      sha256 = "b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d",
    } | Source,
    # The aarch64 7-Zip JNI native. Upstream's `-all-platforms` roll-up
    # deliberately excludes ARM ("WARNING: Not a part of -AllPlatform or
    # -AllLinux !!!"), but the per-platform artifact IS published at the exact
    # version Ghidra vendors. Closes the only genuine arm64/amd64 capability
    # gap in this package.
    #
    # Deliberately SECOND: pkgmgr's updater rewrites only the FIRST sha256, and
    # this pin must NOT track the Ghidra version — upstream froze it in 2016.
    # build.sh asserts the vendored version still matches and fails the build
    # if a Ghidra bump ever revendors it.
    {
      url = "https://repo1.maven.org/maven2/net/sf/sevenzipjbinding/sevenzipjbinding-linux-arm64/16.02-2.01/sevenzipjbinding-linux-arm64-16.02-2.01.jar",
      sha256 = "da89d64861ed45063dc9d655a0c745ca097bd341765d7f0bbedcca1c961d1771",
    } | Source,
    base,
    python, # `python3 -m zipfile` does the extraction
    # The natives upstream does not publish for linux_arm_64 are compiled from
    # the source in the zip above — plain g++/gcc and make, no Gradle, no
    # bison/flex (the generated parsers are checked in upstream and shipped).
    toolchain,
    make,
    zlib, # only the `sleigh` target links it (-lz via the Makefile's $(LNK))
  ],
  runtime_deps = [
    bash, # every launcher is a POSIX shell script
    jdk, # Ghidra 12.x requires JDK 21+; ours is 21.0.10
    # For the natives. These were previously invisible: while they sat inside
    # the `install` OutputData glob the missing-runtime_deps checker skipped
    # them outright (it ELF-parses Binary/Library outputs only), so a native
    # that resolved no libstdc++ would have passed every checker and then
    # failed at exec. Declaring them as OutputBin below turns that check on.
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"], # decompile/sleigh are C++
    zlib, # `sleigh` links libz.so.1
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # `analyzeHeadless` is the point: it is what makes Ghidra scriptable
    # against a fleet of binaries rather than a GUI you drive by hand.
    analyzeHeadless = { glob = "usr/bin/analyzeHeadless" } | OutputBin,
    ghidraRun = { glob = "usr/bin/ghidraRun" } | OutputBin,
    pyghidraRun = { glob = "usr/bin/pyghidraRun" } | OutputBin,

    # The platform natives, declared as real binaries so the checkers actually
    # look at them: output-types asserts the ELF arch matches the target, and
    # missing-runtime_deps resolves their DT_NEEDED against the runtime
    # closure. Both checks are skipped for anything that only matches an
    # OutputData glob — `allow_executable = true` is an explicit no-op arm in
    # the output-types checker, not a weaker assertion — which is how this
    # package used to pass 14/14 while shipping x86_64 ELF on an arm64 target.
    #
    # The `linux_*` wildcard rather than a `match target` branch is deliberate:
    # build.sh keeps exactly one os/linux_* directory (the host's), so this
    # resolves to os/linux_arm_64 here and os/linux_x86_64 on an amd64 builder
    # with no Nickel-level arch dispatch and no second sha256 to maintain.
    decompiler_natives = { glob = "usr/share/ghidra/Ghidra/Features/Decompiler/os/linux_*/*" } | OutputBin,
    demangler_natives = { glob = "usr/share/ghidra/GPL/DemanglerGnu/os/linux_*/*" } | OutputBin,
    fileformats_natives = { glob = "usr/share/ghidra/Ghidra/Features/FileFormats/os/linux_*/*" } | OutputBin,

    # `allow_executable` because the install tree legitimately contains the
    # natives above plus a bundled JNI library (7-Zip's lib7-Zip-JBinding.so).
    # Same shape the jdk package uses for usr/lib/jvm/lib. The globs overlap
    # the three native outputs on purpose — each output is matched and checked
    # independently, so the natives get the strict treatment while the rest of
    # the tree stays a data blob.
    install = { glob = "usr/share/ghidra/**/*", allow_executable = true } | OutputData,
  },

  tests = {
    # THE LOAD-BEARING TEST. Every other check in this package confirms a file
    # EXISTS and has the right ELF arch; this confirms Ghidra actually FINDS
    # AND USES it — which is a different question, and the one that fails
    # silently.
    #
    # When the decompile native is missing or unloadable:
    # DecompileProcessFactory logs once behind a static latch, openProgram()
    # returns false, decompileFunction() short-circuits with errMsg="" so
    # CppExporter's `!"".equals(...)` guard never fires, and analyzeHeadless
    # writes an empty .c and EXITS 0. Worse, that results object is built with
    # DISPOSED_ON_CANCEL, so isCancelled() reports a user cancellation and
    # isValid() returns TRUE for a decompile that produced nothing. Only
    # decompileCompleted() still tells the truth, so the script below is
    # written against that and nothing else.
    #
    # analyzeHeadless has ZERO System.exit calls — it exits 0 when the
    # postScript throws, too. So nothing here trusts its exit code; every
    # assertion is against an artifact the script can only produce by really
    # decompiling.
    #
    # The C++ fixture is deliberately namespaced: `Foo::bar` in names.txt also
    # proves the GNU demangler natives ran, which nothing else here covers and
    # which shipped broken (mode 0644) for the life of this package.
    headless_decompile =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cat > /build/prog.cpp <<'CPP'
              struct Foo { int bar(int a, int b); };
              int Foo::bar(int a, int b) { int c = a * 3; if (b > c) { c = b - c; } return c + 7; }
              int main(void) { Foo f; return f.bar(11, 40); }
              CPP
              cat > /build/DecompParityCheck.java <<'JAVA'
              //Proves Ghidra resolves and uses its platform natives.
              //@category Selftest
              import java.io.File;
              import java.io.PrintWriter;
              import ghidra.app.decompiler.DecompInterface;
              import ghidra.app.decompiler.DecompileResults;
              import ghidra.app.script.GhidraScript;
              import ghidra.program.model.listing.Function;

              public class DecompParityCheck extends GhidraScript {
                  @Override
                  public void run() throws Exception {
                      String[] args = getScriptArgs();
                      if (args.length < 2) { printerr("usage: <out.c> <names.txt>"); return; }
                      StringBuilder names = new StringBuilder();
                      Function target = null;
                      for (Function f : currentProgram.getFunctionManager().getFunctions(true)) {
                          String n = f.getName(true);
                          names.append(n).append('\n');
                          if (n.contains("bar")) { target = f; }
                      }
                      try (PrintWriter w = new PrintWriter(new File(args[1]))) { w.print(names); }
                      if (target == null) { printerr("SELFTEST: no candidate function"); return; }
                      DecompInterface ifc = new DecompInterface();
                      try {
                          if (!ifc.openProgram(currentProgram)) {
                              printerr("SELFTEST: openProgram()==false: " + ifc.getLastMessage());
                              return;
                          }
                          DecompileResults res = ifc.decompileFunction(target, 120, monitor);
                          if (!res.decompileCompleted() || res.getDecompiledFunction() == null) {
                              printerr("SELFTEST: incomplete: " + res.getErrorMessage());
                              return;
                          }
                          String c = res.getDecompiledFunction().getC();
                          if (c == null || c.isBlank()) { printerr("SELFTEST: empty C"); return; }
                          try (PrintWriter w = new PrintWriter(new File(args[0]))) { w.print(c); }
                      } finally { ifc.dispose(); }
                  }
              }
              JAVA
            "%
          ],
          ["/bin/g++", "-O0", "-o", "/build/prog", "/build/prog.cpp"],
          [
            "/bin/analyzeHeadless",
            "/build",
            "parity",
            "-import",
            "/build/prog",
            "-analysisTimeoutPerFile",
            "300",
            "-scriptPath",
            "/build",
            "-postScript",
            "DecompParityCheck.java",
            "/build/decompiled.c",
            "/build/names.txt"
          ],
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              [ -s /build/decompiled.c ] ||
                { echo "no decompiled C: the decompile native did not run" >&2; exit 1; }
              c=$(cat /build/decompiled.c)
              case "$c" in *return*) ;; *)
                echo "no return statement in decompiled C:" >&2; echo "$c" >&2; exit 1 ;; esac
              n=$(cat /build/names.txt)
              case "$n" in *"Foo::bar"*) ;; *)
                echo "GNU demangler native did not run; names still mangled:" >&2
                echo "$n" >&2; exit 1 ;; esac
            "%
          ],
        ],
      } | Test,
  },

  attrs = {
    upstream_version = version,
    # Root LICENSE is verbatim Apache-2.0. The tree aggregates ~20 further
    # licenses (GPL-2.0 WITH Classpath-exception, GPL-3.0, LGPL-2.1/3.0,
    # BSD-2/3, MIT, Zlib, PostgreSQL, MPL-2.0, CC-BY-2.5, Python-2.0,
    # Apache-2.0 WITH LLVM-exception, Bouncy Castle, JDOM, Jython) — ALL
    # OSI/FSF-free, nothing proprietary. Upstream policy (DevGuide.md) keeps
    # GPL code in the standalone top-level `GPL/` module. The natives we now
    # compile do not change this: the decompiler is Apache-2.0, DemanglerGnu
    # is GPL-3.0 (already a separate top-level module for exactly that
    # reason), and lzfse is BSD-3-Clause.
    license_spdx = "Apache-2.0",
  },
} | BuildSpec
