let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let stage0-hex1 = import "../stage0-hex1/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# stage0-kaem: builds kaem-minimal from kaem-minimal.hex0 with the hex0 from stage0-hex1
# (byte-identical to upstream's kaem-optional-seed, 153b8915…), then runs bootstrap.kaem
# under it to rebuild hex0 and hex1. No shell: each cmd is an argv vector, and kaem
# execs coreutils by absolute path and aborts on any non-zero child, so
# `sha256sum -c stage0.answers` is a build-failing byte-identity gate.
# Outputs: usr/bin/{kaem,hex0,hex1}.
let amd64_spec =
  {
    name = "stage0-kaem",
    build_deps = [
      { file = "bootstrap.kaem" } | Local, # kaem script run by the built kaem
      { file = "stage0.answers" } | Local, # sha256sum -c pins for the three outputs
      {
        url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
        sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # same tarball as stage0-hex1
        extract = true,
      } | Source,
      stage0-hex1, # /usr/bin/hex0 and /usr/bin/hex1
      coreutils, # /usr/bin/{chmod,cp,mkdir,sha256sum}, called by absolute path from kaem
    ],
    cmds = [
      ["/usr/bin/hex0", "stage0-posix-1.9.1/AMD64/kaem-minimal.hex0", "/build/kaem-0"],
      ["/usr/bin/chmod", "0755", "/build/kaem-0"],
      # the built kaem runs the rest of the bootstrap
      ["/build/kaem-0", "bootstrap.kaem"],
    ],
    outputs = {
      kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin,
      hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
      hex1 = { glob = "usr/bin/hex1", allow_missing_interpreter = true } | OutputBin,
    },
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-kaem",
      build_deps = [],
    } | BuildSpec,
} target
