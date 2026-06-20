let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let stage0-kaem = import "../stage0-kaem/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# R0 — stage0-mescc.  The rung AFTER B1.5: the on-ramp from kaem to a from-source C
# compiler.  Driven by the ATTESTED kaem-minimal (/usr/bin/kaem, 153b8915… built by
# stage0-kaem) — NOT bash, NOT upstream binaries.  kaem-minimal runs mescc.kaem
# (upstream AMD64/mescc-tools-mini-kaem.kaem, Phases 1-11, with the Phase-1 hex1
# self-rebuild dropped in favour of the attested hex1, all ./paths prefixed for the
# /build root, and an intermediate-sha capture step + sha256sum -c gate + output
# staging (cp then chmod 0755) appended).
#
# The chain: /usr/bin/hex1 -> hex2-0 -> catm -> M0 -> cc_amd64 -> M2 (M2-Planet) ->
# blood-elf-0 -> M1-0 -> hex2-1 -> bin/M1 -> bin/hex2 -> bin/kaem.  The three bin/
# leaves are pinned to upstream amd64.answers (a complete fixed-point gate; see
# stage0.answers).  Every output is a static ELF (no .interp / DT_NEEDED) so
# allow_missing_interpreter=true and there are no runtime_deps; the mini tools are pure
# transforms / linkers (no timestamps, no -j) so the outputs are bit-reproducible.
#
# Trust spine: build_dep stage0-kaem makes B1.5 a genuine predecessor (recursive signer
# walk reaches it, and through it hex0/hex1 + the 229-byte seed).  Source provenance is
# the same sha-pinned tarball as stage0-hex1/stage0-kaem (S3, reused), recorded as a
# sha-pinned resolvedDependency in the attestation.
{
  name = "stage0-mescc",
  build_deps = [
    { file = "mescc.kaem" } | Local, # kaem-minimal-driven mini chain (Phases 1-11)
    { file = "stage0.answers" } | Local, # sha256sum -c pins (kaem-abortable byte-identity gate)
    {
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # S3, reused
      extract = true,
    } | Source,
    stage0-kaem, # attested /usr/bin/{kaem (=kaem-minimal, the driver), hex0, hex1}
    coreutils, # /usr/bin/{sha256sum,mkdir,cp,chmod} — leaf tools kaem execve's by absolute path
  ],
  cmds = [
    # Hand the entire mini-chain sequencing to the attested kaem-minimal. It execve's the
    # mescc tools / attested hex1 / coreutils by path, gates with sha256sum -c, and stages
    # outputs into /build/output. (kaem-minimal takes the script as a positional arg, same
    # invocation form as B1.5's `["/build/kaem-0", "bootstrap.kaem"]`.)
    ["/usr/bin/kaem", "mescc.kaem"],
  ],
  # OUTPUT SURFACE (Q3 resolved).  Every glob is an EXACT filename (no `usr/bin/*`
  # catch-all): coreutils is a build_dep so its tools (cp/mkdir/sha256sum/chmod/ls/…)
  # are hardlinked into the build rootfs at /usr/bin, but (a) the mescc.kaem staging
  # tail copies ONLY these 8 binaries into OUTPUT_DIR, and (b) none of these 8 names is
  # a coreutils tool name — so no coreutils binary is ever shadowed/re-captured here.
  # Durable downstream contract (R0.5/R1/R2 consume): M2-Planet, M1, hex2, kaem,
  # blood-elf, catm.  M0 + cc_amd64 are TRANSITIONAL (superseded inside the chain by
  # M2/M1) — kept as outputs for audit/provenance completeness only; harmless to drop.
  outputs = {
    # GATED by stage0.answers (canonical upstream amd64.answers) — the mescc-tools leaves:
    m1 = { glob = "usr/bin/M1", allow_missing_interpreter = true } | OutputBin,
    hex2 = { glob = "usr/bin/hex2", allow_missing_interpreter = true } | OutputBin,
    # NOTE: this `kaem` is the FULL C kaem (variables/cd/--file), superseding the
    # kaem-minimal we were driven by — it is what drives the later full-kaem/extra phases.
    kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin,
    # NOT individually gated (shas record-at-pin-time) — the from-source C compiler +
    # assembler-support set R0.5/R1 build on.  Their byte-identity is asserted
    # TRANSITIVELY: any divergence would break one of the 3 gated leaves above.
    m2planet = { glob = "usr/bin/M2-Planet", allow_missing_interpreter = true } | OutputBin,
    bloodelf = { glob = "usr/bin/blood-elf", allow_missing_interpreter = true } | OutputBin,
    catm = { glob = "usr/bin/catm", allow_missing_interpreter = true } | OutputBin,
    # transitional (audit/provenance only — superseded by M2/M1 within the chain):
    m0 = { glob = "usr/bin/M0", allow_missing_interpreter = true } | OutputBin,
    cc_amd64 = { glob = "usr/bin/cc_amd64", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec
