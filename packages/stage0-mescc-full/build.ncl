let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let stage0-mescc = import "../stage0-mescc/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# stage0-mescc-full: stage0-posix phases 12-23, which need the full C kaem (cd, variables,
# sub-`kaem --file`). Builds the final self-hosted M2-Planet, M2-Mesoplanet, blood-elf and
# get_machine (mescc-tools-full-kaem), the mescc-tools-extra set including `match`, and
# live-bootstrap's simple-patch helper. This package is the sole toolchain supplier to
# stage0-mes and the tcc rung: it also re-exports kaem, catm, M1 and hex2 so consumers
# import it alone and never stage0-mescc directly (no /usr/bin collision between
# stage0-mescc's bootstrap M2-Planet/blood-elf and the final ones).
#
# Driver: stage0-mescc's full C kaem with --strict; without --strict the full kaem does
# not stop on a failing child. Only stage0-mescc's kaem is in this rootfs: a build_dep
# contributes its runtime closure only, and stage0-mescc has no runtime_deps.
# mescc-full.kaem copies stage0-mescc's tools back into the extracted tree at the paths
# kaem.run expects, runs the upstream full-kaem and extra sub-scripts unmodified, builds
# simple-patch, gates against amd64.answers, and stages the outputs. All writes go to
# the extracted tree or /build/output; /usr is read-only at build time.
let amd64_spec =
  {
    name = "stage0-mescc-full",
    build_deps = [
      { file = "mescc-full.kaem" } | Local, # port of AMD64/kaem.run, phases 12-23
      { file = "stage0.answers" } | Local, # sha256sum -c pins: 19 upstream amd64.answers leaves
      { file = "simple-patch.c" } | Local, # live-bootstrap steps/simple-patch-1.0 source
      {
        url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
        sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # same tarball as stage0-hex1
        extract = true,
      } | Source,
      # Provides the driver /usr/bin/kaem and the five seed inputs mescc-full.kaem copies
      # into the tree: /usr/bin/M2-Planet (artifact/M2), /usr/bin/blood-elf
      # (artifact/blood-elf-0), /usr/bin/{M1,hex2,kaem}.
      stage0-mescc,
      coreutils, # /usr/bin/{mkdir,cp,chmod,sha256sum}, called by absolute path from kaem
    ],
    cmds = [
      ["/usr/bin/kaem", "--strict", "--verbose", "--file", "mescc-full.kaem"],
    ],
    outputs = {
      # The ten tools downstream rungs import. All are static ELFs under usr/bin. Output
      # keys are import handles: renaming one breaks a downstream import.
      #
      # Six tools built by this rung:
      # final self-hosted M2-Planet; live-bootstrap builds mes-m2 with this, not the
      # bootstrap artifact/M2
      m2planet = { glob = "usr/bin/M2-Planet", allow_missing_interpreter = true } | OutputBin,
      # cc driver used to compile the extra tools and simple-patch
      m2mesoplanet = { glob = "usr/bin/M2-Mesoplanet", allow_missing_interpreter = true } | OutputBin,
      # `match`, used by the `if match ${ARCH}` blocks in tcc.kaem. Key is match_tool because
      # `match` is a Nickel keyword.
      match_tool = { glob = "usr/bin/match", allow_missing_interpreter = true } | OutputBin,
      simple_patch = { glob = "usr/bin/simple-patch", allow_missing_interpreter = true } | OutputBin,
      # final blood-elf with debug support, superseding stage0-mescc's blood-elf-0
      bloodelf = { glob = "usr/bin/blood-elf", allow_missing_interpreter = true } | OutputBin,
      get_machine = { glob = "usr/bin/get_machine", allow_missing_interpreter = true } | OutputBin,
      #
      # Four tools re-exported from stage0-mescc, byte-identical to its copies: kaem, M1 and
      # hex2 are the seeded inputs re-asserted by the gate; catm is the M2-Mesoplanet-built
      # one from the extra phase.
      kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin,
      catm = { glob = "usr/bin/catm", allow_missing_interpreter = true } | OutputBin,
      m1 = { glob = "usr/bin/M1", allow_missing_interpreter = true } | OutputBin,
      hex2 = { glob = "usr/bin/hex2", allow_missing_interpreter = true } | OutputBin,
      # Not exported: the extra tools that share names with coreutils (chmod, cp, mkdir, rm,
      # sha256sum, ungz, unbz2, unxz, untar, replace, wrap). They are built and gated in-tree,
      # but staging them would shadow the consumer's coreutils.
    },
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-mescc-full",
      build_deps = [],
    } | BuildSpec,
} target
