let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let stage0-mescc = import "../stage0-mescc/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# R0.5 — stage0-mescc-full. The rung BETWEEN R0 (stage0-mescc, the kaem-minimal-driven mini
# set) and R1 (stage0-mes). It runs the stage0-posix Phase 12-23 ladder that the kaem-minimal
# driver structurally cannot (it needs cd / variables / sub-`kaem --file`): the FINAL self-
# hosted bin/M2-Planet, bin/M2-Mesoplanet, final debuggable bin/blood-elf, bin/get_machine
# (mescc-tools-full-kaem, Phase 12-15) + the mescc-tools-extra util set incl. `match`
# (Phase 16-23) + the live-bootstrap `simple-patch` helper. These are the toolchain R1 (mes)
# and R2 (tcc-0.9.26) actually build on.
#
# DRIVER = R0's OUTPUT full C kaem (/usr/bin/kaem, 6364de59…), run --strict. This is the
# FIRST rung the full kaem drives, and the full kaem only fails-fast under --strict / `set -e`
# (UNLIKE the kaem-minimal that drove B1.5/R0 — see R2-tcc-draft §0A); --strict makes every
# line a build-failing assertion. NOTE the dep model makes /usr/bin/kaem UNAMBIGUOUS: minimal
# only propagates a build_dep's RUNTIME closure transitively (graph/transitives.rs:162-166,
# recursion uses include_build_deps=false), and R0 has no runtime_deps, so stage0-kaem's
# kaem-minimal (153b8915) is NOT pulled into this rootfs — only R0's full kaem is present.
#
# mescc-full.kaem SEEDS R0's installed /usr/bin/{M2-Planet,blood-elf,M1,hex2,kaem} back into
# the freshly-extracted tree (the byte-exact inverse of R0's staging tail), runs the upstream
# AMD64/{mescc-tools-full-kaem,mescc-tools-extra}.kaem sub-scripts UNMODIFIED, compiles
# simple-patch alongside the extra tools, gates against the 19 canonical amd64.answers leaves
# (+ simple-patch RAP), and stages the durable export surface.
#
# Trust spine: build_dep stage0-mescc makes R0 a genuine predecessor (recursive signer walk
# reaches R0 -> stage0-kaem -> hex0/hex1 -> the 229-byte seed). Source is the same sha-pinned
# stage0-posix-1.9.1 tarball (S3, reused), a sha-pinned resolvedDependency. R0.5 writes ONLY
# into the extracted tree + /build/output (never /usr) — it sidesteps the writable-/usr
# question R1/R2 face (CONTRACTS §D: write to /build/output; /usr is read-only at build time).
#
# CROSS-RUNG ROLE (CONTRACTS §A, ratified — supersedes the R0.5-NOTES §2 "R0 rename"): R0.5 is
# the SOLE /usr/bin toolchain supplier to R1 and R2. R1/R2 import THIS package whole and do NOT
# import stage0-mescc (R0) directly, so R0 is NOT rebuilt and there is NO /usr/bin collision
# between R0's bootstrap M2-Planet/blood-elf and R0.5's final ones. To realise that, R0.5
# re-exports the four durable R0-owned tools R1/R2 also need — kaem (the driver), catm, M1,
# hex2 — IN ADDITION to its six final tools (CONTRACTS §B, the 4 `+` rows). Each re-export is
# byte-identical to R0's (M1/hex2/kaem are the SEEDED leaves, gate-re-asserted to the canonical
# shas; catm is the canonical M2-Mesoplanet-built c13daf05). Re-export is unambiguous because
# the dep model leaves only R0's full kaem + coreutils in this rootfs (no self-import).
{
  name = "stage0-mescc-full",
  build_deps = [
    { file = "mescc-full.kaem" } | Local, # full-kaem-driven Phase 12-23 port of AMD64/kaem.run
    { file = "stage0.answers" } | Local, # sha256sum -c gate: 19 canonical pins + simple-patch (RAP)
    { file = "simple-patch.c" } | Local, # live-bootstrap helper source (steps/simple-patch-1.0)
    {
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # S3, reused
      extract = true,
    } | Source,
    # R0: the mini toolchain. Provides the DRIVER /usr/bin/kaem (full C kaem, 6364de59) AND the
    # five SEED inputs mescc-full.kaem plants in-tree: /usr/bin/M2-Planet (== artifact/M2,
    # bootstrap M2), /usr/bin/blood-elf (== artifact/blood-elf-0, no-debug), /usr/bin/{M1,hex2,
    # kaem}. Imported WHOLE as the seed source — UNCHANGED by the §A ratification (R0.5's own
    # build has no collision: only R0 + coreutils are in this rootfs, R0's eight exports share
    # no path with coreutils, and R0.5 stages its outputs to /build/output, never /usr). The §A
    # decision changes only R0.5's OUTPUT surface (re-export kaem/catm/M1/hex2), not this import.
    stage0-mescc,
    coreutils, # /usr/bin/{mkdir,cp,chmod,sha256sum} — seed/gate/stage ops, by absolute path
  ],
  cmds = [
    # Single handoff to R0's attested full C kaem, --strict (fail-fast) + --verbose (trace).
    ["/usr/bin/kaem", "--strict", "--verbose", "--file", "mescc-full.kaem"],
  ],
  outputs = {
    # ── THE R0.5 -> R1/R2 CONTRACT (CONTRACTS §B): the EXACT 10-tool durable surface those ──
    # ── rungs import. All are usr/bin/* static ELFs (allow_missing_interpreter). Output KEYS ──
    # ── are contract handles — renaming a key breaks a downstream import. ──
    #
    # The six FINAL tools (this rung produces them):
    # R1 imports m2planet for the FINAL self-hosted M2-Planet that compiles mes-m2 (live-
    # bootstrap builds mes-m2 with the final bin/M2-Planet, NOT R0's bootstrap artifact/M2).
    m2planet = { glob = "usr/bin/M2-Planet", allow_missing_interpreter = true } | OutputBin, # 7cf19de2
    # R2 imports m2mesoplanet for the M2-Mesoplanet cc-driver (compiles the extra tools +
    # simple-patch; tcc.kaem uses it for the self-contained simple-patch fallback compile).
    m2mesoplanet = { glob = "usr/bin/M2-Mesoplanet", allow_missing_interpreter = true } | OutputBin, # f2485588
    # R2 imports match_tool for `match` (the `if match ${ARCH} …` arch blocks in tcc.kaem).
    # (key is `match_tool`: `match` is a Nickel reserved keyword; the glob sets the path.)
    match_tool = { glob = "usr/bin/match", allow_missing_interpreter = true } | OutputBin, # 962d44ad
    # R2 imports simple_patch for `simple-patch` (the two tcctools.c fopen relocations).
    simple_patch = { glob = "usr/bin/simple-patch", allow_missing_interpreter = true } | OutputBin, # RAP
    # FINAL debuggable blood-elf (6d1c5342). R1 + R2 consume THIS (supersedes R0's no-debug
    # blood-elf-0); live-bootstrap uses the final blood-elf for all post-full-kaem builds.
    bloodelf = { glob = "usr/bin/blood-elf", allow_missing_interpreter = true } | OutputBin, # 6d1c5342
    # get_machine (379cb35a): not consumed by R1/R2; part of the canonical set, for later rungs.
    get_machine = { glob = "usr/bin/get_machine", allow_missing_interpreter = true } | OutputBin,
    #
    # The four RE-EXPORTED durable R0-owned tools (CONTRACTS §A/§B, the `+` rows). R1/R2 take
    # the ENTIRE toolchain from THIS single whole-Build import and never import R0 directly, so
    # nothing in /usr/bin collides. Each is byte-identical to R0's:
    #   kaem/M1/hex2 — the SEEDED leaves, re-asserted by the 19-leaf gate to the canonical shas.
    #   catm         — the canonical M2-Mesoplanet-built catm (c13daf05), built by the extra phase.
    # R0.5-NOTES §2's "catm ownership wrinkle" is hereby resolved: R1/R2 take catm from R0.5,
    # the single gate-asserted owner (c13daf05), NOT R0's hex2-built artifact/catm.
    kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin, # 6364de59 (driver, re-export)
    catm = { glob = "usr/bin/catm", allow_missing_interpreter = true } | OutputBin, # c13daf05 (canonical)
    m1 = { glob = "usr/bin/M1", allow_missing_interpreter = true } | OutputBin, # fc68c115 (re-export)
    hex2 = { glob = "usr/bin/hex2", allow_missing_interpreter = true } | OutputBin, # f782df6d (re-export)
    # DELIBERATELY NOT exported: the coreutils-colliding extra tools (chmod/cp/mkdir/rm/
    # sha256sum/ungz/unbz2/unxz/untar/replace/wrap). All are BUILT + GATED in-tree (part of the
    # 19-leaf fixed point) but staging them would shadow the consumer's coreutils. None of the
    # 10 exported keys above is a coreutils tool name, so R1/R2 keep coreutils as a build_dep
    # with no shadow.
  },
} | BuildSpec
