let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "5.8.3" in
{
  name = "xz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xz-%{version}.tar.xz",
      sha256 = "fff1ffcf2b0da84d308a14de513a1aa23d4e9aa3464d17e64b9714bfdd0bbfb6"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    # Technically bins like xzdiff depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    xz_bin = { glob = "usr/bin/xz" } | OutputBin,
    xzcat = { glob = "usr/bin/xzcat" } | OutputBin,
    xzcmp = { glob = "usr/bin/xzcmp", allow_missing_interpreter = true } | OutputBin,
    xzdec = { glob = "usr/bin/xzdec" } | OutputBin,
    xzdiff = { glob = "usr/bin/xzdiff", allow_missing_interpreter = true } | OutputBin,
    xzegrep = { glob = "usr/bin/xzegrep", allow_missing_interpreter = true } | OutputBin,
    xzfgrep = { glob = "usr/bin/xzfgrep", allow_missing_interpreter = true } | OutputBin,
    xzgrep = { glob = "usr/bin/xzgrep", allow_missing_interpreter = true } | OutputBin,
    xzless = { glob = "usr/bin/xzless", allow_missing_interpreter = true } | OutputBin,
    xzmore = { glob = "usr/bin/xzmore", allow_missing_interpreter = true } | OutputBin,
    lzcat = { glob = "usr/bin/lzcat" } | OutputBin,
    lzcmp = { glob = "usr/bin/lzcmp", allow_missing_interpreter = true } | OutputBin,
    lzdiff = { glob = "usr/bin/lzdiff", allow_missing_interpreter = true } | OutputBin,
    lzegrep = { glob = "usr/bin/lzegrep", allow_missing_interpreter = true } | OutputBin,
    lzfgrep = { glob = "usr/bin/lzfgrep", allow_missing_interpreter = true } | OutputBin,
    lzgrep = { glob = "usr/bin/lzgrep", allow_missing_interpreter = true } | OutputBin,
    lzless = { glob = "usr/bin/lzless", allow_missing_interpreter = true } | OutputBin,
    lzma = { glob = "usr/bin/lzma" } | OutputBin,
    lzmadec = { glob = "usr/bin/lzmadec" } | OutputBin,
    lzmainfo = { glob = "usr/bin/lzmainfo" } | OutputBin,
    lzmore = { glob = "usr/bin/lzmore", allow_missing_interpreter = true } | OutputBin,
    unlzma = { glob = "usr/bin/unlzma" } | OutputBin,
    unxz = { glob = "usr/bin/unxz" } | OutputBin,

    liblzma = { glob = "usr/lib/liblzma.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "xz (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/f0fc73ed269bb9cfa7e31e14330c6b2f7fdff6aea005df85f81ca626855afaf0/stage0-xz-amd-x86_64.tar.zst",
              sha256 = "f0fc73ed269bb9cfa7e31e14330c6b2f7fdff6aea005df85f81ca626855afaf0",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/a94b810187b72dc9144270f834b867be883e7cf5db155e4ac1b0dc0fabd0f2a8/stage0-xz-arm-aarch64.tar.zst",
              sha256 = "a94b810187b72dc9144270f834b867be883e7cf5db155e4ac1b0dc0fabd0f2a8",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "(0BSD AND GPL-2.0-only AND GPL-3.0-only AND LGPL-2.1-only)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tukaani-project",
        repo = "xz",
      },
    } | Attrs,
} | BuildSpec
