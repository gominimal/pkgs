let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "4.10" in
{
  name = "sed",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sed-%{version}.tar.xz",
      sha256 = "b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7"
    } | Source,
    acl,
    bash-bootstrap,
    binutils,
    coreutils,
    findutils,
    gawk-bootstrap,
    gcc,
    glibc,
    grep,
    linux_headers,
    make,
    sed,
    tar,
  ],
  runtime_deps = [
    acl,
  ],

  cmd = "./build.sh",
  outputs = {
    sed = { glob = "usr/bin/sed" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "sed",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "sed (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/sed/b2454441fcc0966caa42b1a66c39de67ed9f4fbf507443a4443313b2d955e43d.tar.zst",
              sha256 = "0545b519704c923b41c2a704eb5162245f7496d35df09deeb051f54a7a218bed",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK EXECUTOR ROOT (aarch64): built on the ladder by rd85-armd-userland.sh with
              # R12 gcc + R11 glibc. These seven RUN every build and cannot be built from inside
              # pkgs (a shell is needed to build a shell); the ladder has no such constraint, the
              # same reason gcc was never built inside a gcc-free sandbox.
              # GATED slot-compare vs the foreign slot. COMPILED BY our hex0-rooted gcc against our
              # hex0-rooted glibc; EXECUTED during its build by the VM's Debian tools -- exactly
              # R12's standing, NOT "built with no foreign tool present".
              # BEDROCK ROOT: hex0-rooted artifact replacing the bootstrap-aarch64-bins
              # (dockcross/crosstool-NG) prebuilt. Provenance + seals: minimermetic#16.
              # Applied by bin/queue/update-bedrock-roots.py from bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/c3870ea3e87cc8fe28cc45df8fb21401cbb137097e86a7171396204adb4a82df/stage0-sed-bedrock-aarch64.tar.zst",
              sha256 = "c3870ea3e87cc8fe28cc45df8fb21401cbb137097e86a7171396204adb4a82df",
              extract = true,
            } | Source,
        } target,
      ],
      # TODO: runtime_deps in a cycle breaker are borked?
      # runtime_deps = [
      #   acl,
      #   attr,
      # ],
      outputs = {
        sed = { glob = "usr/bin/sed" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/sed --version",

    text =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          # verify substitution
          ["/bin/bash", "-c", "echo 'hello world' > input.txt"],
          ["/bin/bash", "-c", "sed 's/world/universe/' input.txt > output.txt"],
          ["/bin/bash", "-c", "grep -q 'hello universe' output.txt"],
          # verify in-place edit
          ["/bin/bash", "-c", "echo 'hello world' > input2.txt"],
          ["/bin/sed", "-i", "s/hello/hi/", "input2.txt"],
          ["/bin/bash", "-c", "grep -q '^hi world$' input2.txt"],
          # verify line extraction
          ["/bin/bash", "-c", "echo 'line1\nline2\nline3' > multi.txt"],
          ["/bin/bash", "-c", "sed -n '2p' multi.txt | grep -q '^line2$'"],
        ],
      } | Test,
  },
} | BuildSpec
