let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let version = "6.12.43" in
{
  name = "linux_headers",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee"
    } | Source,
    bash-bootstrap,
    coreutils,
    findutils,
    grep,
    make,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers
  ],
  cmd = "./build.sh",
  outputs = {
    includes = { glob = "usr/include/*/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "linux_headers (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/083cdb678eb2a154373819a5b3511b2b0e73c6261a010dce896287c742be83c3/stage0-linux-headers-6.12.43-6.12.43.tar.zst",
              sha256 = "083cdb678eb2a154373819a5b3511b2b0e73c6261a010dce896287c742be83c3",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/862f0245057fb5210c22ad09a537ab099d4672754052328a290a5c9b698dee76/stage0-linux-headers-arm-aarch64.tar.zst",
              sha256 = "862f0245057fb5210c22ad09a537ab099d4672754052328a290a5c9b698dee76",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        includes = { glob = "usr/include/*/**" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Linux-syscall-note",
      source_provenance = {
        category = 'GithubRepo,
        owner = "torvalds",
        repo = "linux",
      },
    } | Attrs,
} | BuildSpec
