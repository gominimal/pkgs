let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
# ---- the compiler half: this rung's toolchain, all tcc-built, no gcc anywhere ----
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in
let stage0-musl-1_1_24-cc2 = import "../stage0-musl-1.1.24-cc2/build.ncl" in
let stage0-binutils-2_30 = import "../stage0-binutils-2.30/build.ncl" in
# ---- the BUILD-TIME HOST ENVIRONMENT — see "WHAT THIS RUNG DOES NOT DO" §B below ----
# ./configure and make invoke every one of these. They were previously UNDECLARED, which is
# strictly worse than declaring them: an undeclared edge is invisible to the attestation walk
# while still being entirely real. Declared, it lands in resolvedDependencies and can be argued
# about. This is a correction of fact, not a change of ambition.
let bash = import "../bash/build.ncl" in # /usr/bin/sh: the `cmds` interpreter AND ./configure's
let make = import "../make/build.ncl" in # the build engine
let sed = import "../sed/build.ncl" in # configure; automake's $(transform) (ginstall -> install)
let grep = import "../grep/build.ncl" in # configure probes; build.sh's musl-marker assertion
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in # AC_PROG_AWK; config.status
let diffutils = import "../diffutils/build.ncl" in # config.status "config.h is unchanged" (diff)
let coreutils = import "../coreutils/build.ncl" in # rm/mkdir/cat/cut/chmod/install/sha256sum — §B

# ======================= VERSION DECISION POINT — THE ONLY ONE IN THIS RUNG =======================
# CHANGE `version` AND `sha256` TOGETHER, HERE, AND NOWHERE ELSE. Everything downstream derives
# from `version`: the mirrored tarball URL, the srcdir build.sh cds into (via build_args), and
# attrs.upstream_version. build.sh hardcodes no version.
#
# 5.0 is currently pinned and 5.0 CANNOT satisfy the bedrock's actual requirement — see the MEASURED
# block immediately below, which is the evidence, and `outputs.sha256sum`, which is the second and
# last place a version bump has to touch. The SHA-2 question is being settled separately; until it
# lands, this rung is correct-for-5.0 and honest about what 5.0 cannot do.
let version = "5.0" in

# stage0-coreutils — coreutils built by the bedrock's own tcc-musl rung, never by gcc.
#
# WHAT THIS RUNG DOES. Compiles coreutils with stage0-tcc-0.9.27-musl-s4 + stage0-musl-1.1.24-cc2 +
# stage0-binutils-2.30 and nothing else on the COMPILER side. That is a real, checkable claim, and
# it is the claim the gate at the tail of build.sh tests.
#
# WHAT THIS RUNG DOES NOT DO — READ BEFORE CITING IT. Two corrections from the 2026-08-01
# adversarial audit (minimermetic d86c2fd), both contradicting this file's first version:
#
#   A. IT DOES NOT "CUT THE KEYSTONE EDGE". Simulated over all 24 stage0 rungs, swapping
#      coreutils -> stage0-coreutils leaves 24/24 still reaching {gcc, glibc, binutils,
#      linux_headers}; so does deleting the edge outright. coreutils is the highest-fanout of
#      FOURTEEN cycle-forming userland edges. bash is CO-EQUAL, not a later cleanup:
#      stage0-hex1/build.ncl imports it and uses it as the build.sh interpreter at RUNG 1, so it is
#      recursively charged to 24/24 exactly as coreutils is. coreutils + bash together still cleans
#      only 4/24. The cut is the UNION of the fourteen; no proper subset works.
#
#   B. IT STILL CONSUMES `coreutils` AND `bash` AT BUILD TIME, AND NOW SAYS SO. ./configure is a
#      shell script that runs rm/mkdir/cat/sed/grep/awk/diff several thousand times; `make install`
#      needs install + sed. There is no version of this recipe that runs ./configure and omits them.
#      The honest options were (i) declare them, or (ii) pre-generate config.h and drive make from
#      kaem the way live-bootstrap does. (ii) is the real fix and is a separate increment; until it
#      lands, (i) is what is true, so (i) is what is written.
#      DIRECT CONSEQUENCE, STATED PLAINLY: as declared, THIS RUNG IS ITSELF CIRCULAR THROUGH
#      `coreutils`. No stage0-* rung may import it yet — doing so creates a genuine dependency
#      cycle rather than breaking one.
#      AND THE DECLARATION COSTS NOTHING, MEASURED 2026-08-02 by walking the import graph:
#      the transitive closure of stage0-coreutils is 61 packages with these seven declared and
#      61 packages without them — every one of bash, make, sed, grep, gawk-bootstrap, diffutils
#      and coreutils was ALREADY in the closure via stage0-binutils-2.30 and
#      stage0-tcc-0.9.27-musl-s4, both of which import them outright. The closure reached
#      {gcc, glibc, binutils, linux_headers} BEFORE this change and reaches them after. So the
#      old recipe's "DELIBERATELY NOT DEPENDED ON: coreutils, bash" was never true of the closure;
#      it was true only of the one file you happened to be reading. Declaring them makes a real
#      edge visible and adds nothing.
#
# WHY coreutils 5.0. Modern coreutils (9.x) requires a full autotools configure whose probes and
# gnulib vintage assume a much newer toolchain. 5.0 (2003) is what live-bootstrap uses at an
# equivalent rung. Mirrored 2026-07-31; sha256 at the Source entry below.
#
# ============================ MEASURED 2026-08-02: THIS RUNG CANNOT PASS ============================
# coreutils 5.0 SHIPS NO SHA-2. Measured by extracting the tarballs, not inferred:
#
#   version | sha256sum in src/Makefile.am bin_PROGRAMS | lib/sha256.c | first musl/tcc wall
#   --------+-------------------------------------------+--------------+---------------------------
#   5.0     | NO                                        | NO           | (n/a)
#   5.3.0   | NO                                        | NO           | (n/a)   <- the UNVERIFIED
#   5.97    | NO                                        | NO           | (n/a)      guess; refuted
#   6.0-6.2 | YES  (NEWS: "New programs" @ 6.0)         | YES          | futimens 3-arg
#   6.3-6.9 | YES                                       | YES          | futimens 3-arg
#   6.10+   | YES                                       | YES          | gnulib freadahead/fseterr/
#           |                                           |              | fpurge/freading #error
#
# So `outputs.sha256sum = usr/bin/sha256sum` can never match and build.sh's CU-GATE can never pass
# at version = "5.0". Bumping to 6.x is not free either: lib/utimens.h in 6.0-6.9 declares
#   int futimens (int, char const *, struct timespec const [2]);
# while musl 1.1.24 declares, UNGUARDED, at include/sys/stat.h:91
#   int futimens(int, const struct timespec [2]);
# -> incompatible redeclaration in every TU that includes both (src/copy.c, src/touch.c).
# 6.10+ renames it gl_futimens but replaces that wall with four gnulib files that #error on any
# libc whose FILE internals they don't recognise. No 6.x release is free of both.
#
# STRUCTURAL PROBLEM, ALSO MEASURED: of the 11 LIVE (uncommented) `sha256sum` call sites in the
# bedrock recipes, 10 are inside THIS rung's own transitive build_dep closure (stage0-kaem,
# stage0-hex1, stage0-mescc, stage0-mescc-full, stage0-mes, stage0-tcc-0.9.26, stage0-tcc-0.9.27,
# stage0-tcc-0.9.27-musl-s4, stage0-musl-1.1.24, stage0-musl-1.1.24-cc2). A coreutils built HERE
# can never supply sha256sum to any of them without a cycle. It would serve exactly one live user
# outside its own closure: stage0-musl-1.2.5.
#
# THE ALTERNATIVE ALREADY IN THE TREE: stage0-mescc-full (R0.5) ALREADY builds mescc-tools-extra's
# sha256sum with M2-Planet and ALREADY byte-pins it in its stage0.answers
# (f7c0fcae688ec01050d836771392f4d81f5ad6788590278ec76ccd17cdd89e48), together with chmod, cp,
# mkdir and rm -- i.e. this rung's entire OutputBin set minus cat/sort/tr/install -- and then
# deliberately does not export them. See the report for the two gaps that must be closed first
# (no stdin mode -> `sha256sum < f` is a FAIL-OPEN vacuous pass; `-c` rejects comment lines).
# ===================================================================================================
#
# THE COMPILER-SIDE FLAGS WERE MEASURED, NOT GUESSED. The 2026-07-31 amd64 probe
# (minimermetic bedrock-aarch64/tools/coreutils-amd64-proof.sh) hit these walls in order, and each
# entry below is its cure:
#
#   1. crt1.o/crti.o "not found" though present  -> the rung artifacts are built expecting to LIVE
#      at /usr; tcc's crt and include paths are baked. The sandbox installs them there, so no flag
#      is needed here — but it is why a bare-VM reproduction fails and this must be a package.
#   2. bits/alltypes.h ';' expected (got "va_list")  -> WRONG MUSL. stage0-musl-1.2.5 is the
#      GCC-built stock musl ("ZERO of R4's tcc-workaround patches", per its own recipe).
#      stage0-musl-1.1.24-cc2 is the TCC-built one, carrying amd64-va-list.patch which defines
#      __builtin_va_list via tcc's SysV __va_list_struct (__TINYC_va_list_defined).
#   3. "no acceptable ld found in $PATH"  -> stage0-binutils-2.30, itself tcc-built, so no gcc
#      dependency is introduced.
#   4. alloca.h:11 incompatible types for redefinition of 'alloca'  -> musl declares
#      `void *alloca(size_t)` while tcc has a builtin of a different type. -D_ALLOCA_H makes the
#      header a no-op via its own include guard; the header on disk is untouched. THIS FLAG IS
#      MUSL-ONLY — on glibc it is actively harmful, so it must never migrate to a glibc rung.
#   5. undefined symbol 'alloca' at link  -> the coherent configure answer. Saying
#      header=no AND works=yes meant neither <alloca.h> NOR coreutils' own lib/alloca.c was used.
#      works=no builds the portable fallback, which supplies the symbol.
#   6. incompatible types for redefinition of 'getline' (this killed md5sum.o and dircolors.o)
#      -> -D__GLIBC__=2. Verified by reading the shipped header rather than inferring: coreutils
#      5.0's lib/getline.h:30 guards its own declarations with `# if __GLIBC__ < 2` and NOTHING
#      ELSE, and src/md5sum.c:31 includes it unconditionally. musl leaves __GLIBC__ undefined, so
#      in #if it is 0, 0 < 2 is true, and the declaration lands on top of musl's. The recipe's
#      `ac_cv_func_getline=yes` provably cannot suppress this — a cache var decides whether
#      lib/getline.c is COMPILED, not whether a header emits a bare declaration.
#   7. undefined symbol '__mempcpy' (csplit, nl)  -> -D__mempcpy=mempcpy, the follow-on cost of
#      claiming __GLIBC__=2: 5 files under lib/ (fnmatch.c, strftime.c, ftw.c, getopt.c, regex.c)
#      reach for glibc's internal alias, which musl does not export. musl does provide mempcpy
#      under _GNU_SOURCE, so the mapping is exact rather than a stub.
#
# WALLS 6 AND 7 WERE MISSING FROM THIS RECIPE UNTIL 2026-08-02: it was committed 77 minutes before
# the probe that measured them passed.
#
# STATUS, in this repo's vocabulary (BUILT < GATED < ATTESTED < SEALED < operator-pinned):
# NOT EVEN BUILT. No CS build of this package has ever completed; until 2026-08-02 it could not
# even be DECODED (the `version` field and the missing stage0.answers below). The amd64 probe that
# informs the flags ran on a bare VM outside CS, reported `make rc=2`, and produced 5 of ~90 tools.
# Nothing here may be described as passing until the gate in build.sh runs green in the builder.
{
  name = "stage0-coreutils",
  # NOTE: there is deliberately NO `version = ...` FIELD HERE. minimal.ncl's BuildSpec is a CLOSED
  # record contract with no `version` member, so the field this recipe used to carry made the
  # WHOLE 492-package layer fail to evaluate with "extra field `version`" — before any Local file
  # was read and long before a container started. The version lives in the `let` binding above and
  # reaches build.sh through build_args.
  build_deps = [
    { file = "build.sh" } | Local,
    # BYTE-IDENTITY SEAL, record-at-pin-time — the convention 19 sibling packages already follow.
    # THIS FILE MUST EXIST ON DISK. decode reads every `| Local` input eagerly and PANICS THE WHOLE
    # PROCESS if it cannot: minimermetic hermetic-builder-rs/vendor/minimal/crates/decode/src/
    # builds.rs:552 does
    #     blake3::hash(&std::fs::read(&full_path).unwrap_or_else(|err| panic!(
    #         "Local input could not be read: {} (file: {})", err, full_path.display())))
    # with no fallback and no Result. It was declared here but never committed, so this one package
    # aborted decoding of the entire layer. It now ships an `# UNPINNED` placeholder AND build.sh
    # actually reads it (record mode) — a declared input that nothing consumes is decoration, and
    # decoration is how vacuous passes start.
    { file = "stage0.answers" } | Local,
    {
      url = "gs://minimal-staging-archives/coreutils-%{version}.tar.gz",
      # 5.0: re-confirmed in the mirror 2026-08-02 (6020616 B) and re-hashed from the fetched copy.
      # CHANGE THIS TOGETHER WITH `version` AT THE TOP — nowhere else.
      sha256 = "c27ce75e3f62455f4facf4f3fd55bc9e3877d0ab1d5c0426c94da168cc349883",
      extract = true,
    } | Source,
    # ---- compiler side: no gcc, no glibc ----
    stage0-tcc-musl-s4, # the compiler: tcc-musl2 + libtcc1.a (the "alloca provider")
    stage0-musl-1_1_24-cc2, # the TCC-COMPATIBLE musl — see wall 2 above
    stage0-binutils-2_30, # as/ld — see wall 3
    # ---- host side: declared because it is USED, not because it is wanted (§B above) ----
    bash,
    make,
    sed,
    grep,
    gawk-bootstrap,
    diffutils,
    coreutils,
  ],
  build_args = {
    include version, # build.sh derives the srcdir from this and hardcodes no version
  },
  # Explicit interpreter rather than a shebang, because it names WHICH package supplies the shell:
  # /usr/bin/sh is bash's `sh` OutputBin. ("/bin/sh" would also resolve, via the /usr/bin -> /bin
  # symlink sandbox2 creates when no package supplies a real /bin, but that is an implicit property
  # of the sandbox and this rung has had enough implicit dependencies.)
  cmds = [
    ["/usr/bin/sh", "build.sh"],
  ],
  outputs = {
    # The tool surface the bedrock rungs actually name, measured across packages/stage0-*/build.sh.
    # An OutputBin whose glob matches nothing FAILS the build, so this list is a fail-shut contract.
    # chmod/cp/mkdir/rm are the four the amd64 probe observed; cat/sort/tr/install are named by one
    # rung and are UNPROVEN — but all four are in 5.0's src/Makefile.am bin_PROGRAMS, so they are
    # unproven-but-possible, which is a different category from sha256sum below. If they do not
    # build, this build must go red; that is the intent.
    chmod = { glob = "usr/bin/chmod" } | OutputBin,
    cp = { glob = "usr/bin/cp" } | OutputBin,
    mkdir = { glob = "usr/bin/mkdir" } | OutputBin,
    rm = { glob = "usr/bin/rm" } | OutputBin,
    cat = { glob = "usr/bin/cat" } | OutputBin,
    sort = { glob = "usr/bin/sort" } | OutputBin,
    tr = { glob = "usr/bin/tr" } | OutputBin,
    install = { glob = "usr/bin/install" } | OutputBin, # automake's $(transform) renames ginstall
    # THE GATE INSTRUMENT, AND NOTHING MORE. A hash tool is the cheapest way to prove the compiler
    # emitted code that COMPUTES correctly rather than merely executes, and md5sum is the only one
    # 5.0 ships. Listed here because build.sh's functional gate consumes it.
    # NO BEDROCK RUNG USES md5sum — ZERO of the 24 stage0 build.sh invoke it. Certifying md5sum is
    # therefore evidence about the COMPILER, not about the capability the ladder needs. The first
    # two proofs of this rung mistook the one for the other; do not repeat that.
    md5sum = { glob = "usr/bin/md5sum" } | OutputBin,
    # !! sha256sum IS DELIBERATELY ABSENT, AND THAT IS THE OPEN PROBLEM, NOT AN OVERSIGHT !!
    # This line used to read `sha256sum = { glob = "usr/bin/sha256sum" } | OutputBin` and build.sh
    # hard-exited on the file. coreutils 5.0 contains zero references to sha256 anywhere in the
    # tree, so that was a STRUCTURALLY UNSATISFIABLE gate: red at every flag setting, forever, for
    # any amount of debugging — as distinct from the merely-unproven cat/sort/tr/install above.
    # 11 of 24 stage0 build.sh DO invoke sha256sum, so the requirement is real; 5.0 is simply the
    # wrong instrument for it. Restoring this line is HALF of the VERSION DECISION POINT at the top
    # of this file (the other half is `version` + `sha256`), and it must not be done on its own.
    #   sha256sum = { glob = "usr/bin/sha256sum" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "coreutils",
    } | Attrs,
} | BuildSpec
