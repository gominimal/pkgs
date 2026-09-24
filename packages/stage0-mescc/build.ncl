let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let stage0-kaem = import "../stage0-kaem/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# stage0-mescc: the mescc-tools mini chain from stage0-posix-1.9.1, driven by the
# kaem-minimal from stage0-kaem running mescc.kaem (upstream
# AMD64/mescc-tools-mini-kaem.kaem phases 2-11 with paths prefixed for /build, plus a
# sha256sum -c gate and output staging).
# Chain: hex1 -> hex2-0 -> catm -> M0 -> cc_amd64 -> M2 (M2-Planet) -> blood-elf-0 ->
# M1-0 -> hex2-1 -> bin/M1 -> bin/hex2 -> bin/kaem. The three bin/ leaves are pinned to
# upstream amd64.answers in stage0.answers. Outputs are static ELFs with no .interp.
let amd64_spec =
  {
    name = "stage0-mescc",
    build_deps = [
      { file = "mescc.kaem" } | Local,
      { file = "stage0.answers" } | Local, # sha256sum -c pins
      {
        url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
        sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df", # same tarball as stage0-hex1
        extract = true,
      } | Source,
      stage0-kaem, # /usr/bin/{kaem (kaem-minimal, the driver), hex0, hex1}
      coreutils, # /usr/bin/{sha256sum,mkdir,cp,chmod}, called by absolute path from kaem
    ],
    cmds = [
      # kaem-minimal takes the script as a positional argument.
      ["/usr/bin/kaem", "mescc.kaem"],
    ],
    # Every glob is an exact filename: coreutils is in the rootfs at /usr/bin, and none of
    # these eight names is a coreutils tool, so no coreutils binary is re-captured.
    # M0 and cc_amd64 are superseded within the chain and kept only for provenance.
    outputs = {
      # pinned by stage0.answers
      m1 = { glob = "usr/bin/M1", allow_missing_interpreter = true } | OutputBin,
      hex2 = { glob = "usr/bin/hex2", allow_missing_interpreter = true } | OutputBin,
      # the full C kaem (variables, cd, --file), not the kaem-minimal that drove this build
      kaem = { glob = "usr/bin/kaem", allow_missing_interpreter = true } | OutputBin,
      # not pinned individually; any divergence would change one of the three leaves above
      m2planet = { glob = "usr/bin/M2-Planet", allow_missing_interpreter = true } | OutputBin,
      bloodelf = { glob = "usr/bin/blood-elf", allow_missing_interpreter = true } | OutputBin,
      catm = { glob = "usr/bin/catm", allow_missing_interpreter = true } | OutputBin,
      m0 = { glob = "usr/bin/M0", allow_missing_interpreter = true } | OutputBin,
      cc_amd64 = { glob = "usr/bin/cc_amd64", allow_missing_interpreter = true } | OutputBin,
    },
  } | BuildSpec
in
# amd64 only. arm64 consumes prebuilt bedrock artifacts as sha-pinned Sources instead,
# so on arm64 this spec is an empty collection: nothing builds and nothing depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-mescc",
      build_deps = [],
    } | BuildSpec,
} target
