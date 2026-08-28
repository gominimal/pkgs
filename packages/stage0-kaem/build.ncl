let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let stage0-hex1 = import "../stage0-hex1/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# B1.5 — kaem as a from-source attested artifact, and the rung that RETIRES bash as the
# bootstrap driver. kaem-minimal is NOT a seed: it is hex0(kaem-minimal.hex0), byte-identical
# to upstream's kaem-optional-seed (153b8915…). We derive it with the hex0 attested by
# stage0-hex1, then hand the bootstrap sequencing to that kaem (bootstrap.kaem). No /bin/sh:
# every cmd is an explicit argv vector execve'd by minimal; kaem then execve's coreutils leaf
# tools by absolute path (it has no PATH search, no cd, no env, no redirection, and aborts HARD
# on any non-zero child — so `sha256sum -c stage0.answers` is a build-failing byte-identity gate).
# Seed floor stays at the 229-byte hex0 alone; kaem joins the catalogue as a DERIVED artifact.
{
  name = "stage0-kaem",
  build_deps = [
    { file = "bootstrap.kaem" } | Local, # kaem-language driver script (sequences the bootstrap)
    { file = "stage0.answers" } | Local, # sha256sum -c pins (kaem-abortable byte-identity gate)
    {
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # S3, reused from stage0-hex1
      extract = true,
    } | Source,
    stage0-hex1, # provides attested /usr/bin/hex0 (== seed 66c95985…) and /usr/bin/hex1
    coreutils, # /usr/bin/{chmod,cp,mkdir,sha256sum} — leaf tools kaem execve's by absolute path
  ],
  cmds = [
    # 1. derive kaem from auditable source with the attested hex0 (stage0-posix Phase-0b)
    ["/usr/bin/hex0", "stage0-posix-1.9.1/AMD64/kaem-minimal.hex0", "/build/kaem-0"],
    # 2. make it runnable (coreutils chmod, execve'd directly — no shell)
    ["/usr/bin/chmod", "0755", "/build/kaem-0"],
    # 3. HAND OFF: the just-built kaem drives the bootstrap steps  <-- retires bash as driver
    ["/build/kaem-0", "bootstrap.kaem"],
  ],
  outputs = {
    kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin,
    hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
    hex1 = { glob = "usr/bin/hex1", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec
