let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # M2-Planet, kaem, catm, M1, hex2, blood-elf
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
# stage0-mes: GNU Mes 0.27.1. M2-Planet compiles mes-m2 (a subset-C port of the Mes
# Scheme interpreter); mes-m2 runs MesCC to build mes-libc (crt1.o, libc.a, libc+tcc.a,
# libmescc.a) and regenerate nyacc's parser tables. Outputs: mes-m2, mescc.scm, the
# mes-libc tree and headers, and the Scheme module trees the next rung (tcc) needs.
# Driver: the full C kaem from stage0-mescc-full running mes.kaem, a port of
# live-bootstrap steps/mes-0.27.1/pass1.kaem. kaem aborts on any non-zero child, so
# `sha256sum -c mes.answers` is a build-failing gate.
let amd64_spec =
  {
    name = "stage0-mes",
    build_deps = [
      { file = "mes.kaem" } | Local, # port of live-bootstrap pass1.kaem
      { file = "mes.answers" } | Local, # sha256sum -c pins for the outputs
      { file = "config.h" } | Local, # live-bootstrap files/config.h (SYSTEM_LIBC undef + MES_VERSION)
      {
        # GNU Mes 0.27.1; sha as published by live-bootstrap steps/mes-0.27.1/sources.
        url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
        sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
        extract = true,
      } | Source,
      {
        # nyacc 1.00.2-lb1, the live-bootstrap fork release; the Scheme C99 parser MesCC uses.
        # Extracts to nyacc-1.00.2 (see NYACC_DIR in mes.kaem).
        url = "gs://minimal-staging-archives/nyacc-1.00.2-lb1.tar.gz",
        sha256 = "708c943f89c972910e9544ee077771acbd0a2c0fc6d33496fe158264ddb65327",
        extract = true,
      } | Source,
      {
        # stage0-posix tree, for the M2libc that the inner M2-Planet build of mes-m2 needs
        # (M2LIBC_PATH); mes 0.27.1 does not ship M2libc.
        url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
        sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df",
        extract = true,
      } | Source,
      # mes-m2 must be built with the final self-hosted bin/M2-Planet (as live-bootstrap's
      # seed.kaem does), which stage0-mescc-full provides; stage0-mescc only emits artifact/M2.
      stage0-mescc-full, # /usr/bin/{M2-Planet,kaem,catm,M1,hex2,blood-elf,M2-Mesoplanet,match,simple-patch,get_machine}
      coreutils, # /usr/bin/{mkdir,cp,rm,chmod,sha256sum}
      tar, # /usr/bin/tar
      gzip, # /usr/bin/gzip
      sed, # /usr/bin/sed, replaces live-bootstrap's `replace` and `simple-patch`
    ],
    cmds = [
      # The full kaem requires --file for the script; a bare positional argument is an error.
      # PATH, cd and control flow live inside mes.kaem.
      ["/usr/bin/kaem", "--strict", "--verbose", "--file", "mes.kaem"],
    ],
    outputs = {
      # static ELF from M2-Planet/hex2, no .interp
      mes_m2 = { glob = "usr/bin/mes-m2", allow_missing_interpreter = true } | OutputBin,
      # MesCC driver script, run as `mes-m2 -e main mescc.scm`
      mescc_scm = { glob = "usr/bin/mescc.scm", allow_executable = true } | OutputData,
      # mes-libc: crt1.{o,s}, libc.{a,s}, libc+tcc.{a,s}, libmescc.{a,s}, x86_64.M1
      mes_libs = { glob = "usr/lib/x86_64-mes/**" } | OutputData,
      # ELF header/footer hex2 fragments used by the mes/tcc link step
      mes_linux_libs = { glob = "usr/lib/linux/x86_64-mes/**" } | OutputData,
      mes_includes = { glob = "usr/include/**" } | OutputData,
      # Copy of the same headers at a path no other package writes: /usr/include is also
      # populated by glibc in consumer sandboxes, so shell-driven consumers compile
      # -nostdinc against this copy instead.
      mes_sysroot_inc = { glob = "usr/lib/mes-bedrock/include/**" } | OutputData,
      # Scheme module trees (mes core + mescc + regenerated nyacc c99 tables). Not installed
      # by upstream pass1.kaem; shipped so the next rung can set GUILE_LOAD_PATH to them.
      mes_modules = { glob = "usr/share/mes/**" } | OutputData,
      nyacc_modules = { glob = "usr/share/nyacc/**" } | OutputData,
    },
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-mes",
      build_deps = [],
    } | BuildSpec,
} target
