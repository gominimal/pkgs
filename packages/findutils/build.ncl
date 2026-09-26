let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "4.11.0" in
{
  name = "findutils",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/findutils-%{version}.tar.xz",
      sha256 = "bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
    bash-bootstrap,
    binutils,
    coreutils,
    diffutils,
    gawk-bootstrap,
    gcc,
    glibc,
    grep,
    make,
    linux_headers,
    sed,
    tar,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    find = { glob = "usr/bin/find" } | OutputBin,
    locate = { glob = "usr/bin/locate" } | OutputBin,
    # Technically updatedb depends on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    updatedb = { glob = "usr/bin/updatedb", allow_missing_interpreter = true } | OutputBin,
    xargs = { glob = "usr/bin/xargs" } | OutputBin,

    libexec_frcode = { glob = "usr/libexec/frcode" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "findutils",
      },
      license_spdx = "GPL-3.0-only",
      repology_project = "findutils",
    } | Attrs,

  replace_on_cycle =
    {
      name = "findutils (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/f6f35466213d8c0432614a46b4c2827e1ddf531ea316ded0b44ec8f2a14ab6ce/stage0-findutils-amd-x86_64.tar.zst",
              sha256 = "f6f35466213d8c0432614a46b4c2827e1ddf531ea316ded0b44ec8f2a14ab6ce",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/0e5ca2adcedc9c949859438103cae0635ab7714363626fd6e4e06b58a59bc0d8/stage0-findutils-arm-aarch64.tar.zst",
              sha256 = "0e5ca2adcedc9c949859438103cae0635ab7714363626fd6e4e06b58a59bc0d8",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/find --version",

    find =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "mkdir -p testdir && echo 'data' > testdir/test.txt"],
          ["/bin/bash", "-c", "touch testdir/other.log"],
          # verify find result
          ["/bin/bash", "-c", "find testdir -name '*.txt' | grep -q 'test.txt'"],
          # verify 2 files
          ["/bin/bash", "-c", "find testdir -type f | wc -l | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
