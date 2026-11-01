let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.15" in
{
  name = "gzip",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gzip-%{version}.tar.xz",
      sha256 = "9aa0cc780dec156b8282844833b342ab7cb08c25d2cd9a1869cdd0df31deff48"
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
    # Technically bins like zgrep depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      repology_project = "gzip",
      source_provenance = {
        category = 'GnuProject,
        name = "gzip",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "gzip (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/7b4858480866296e4a3b9a498ebd6e1175ca37ae2235cd856c40b5c5a525a1fc/gzip-x86_64.tar.zst",
              sha256 = "7b4858480866296e4a3b9a498ebd6e1175ca37ae2235cd856c40b5c5a525a1fc",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/f41e067fe874a8ec8821b0a060eb2c68e1173282d7cbce1dca14d9f6059f1a22/gzip-aarch64.tar.zst",
              sha256 = "f41e067fe874a8ec8821b0a060eb2c68e1173282d7cbce1dca14d9f6059f1a22",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        binaries = { glob = "usr/bin/*" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/gzip --version",

    zip_unzip =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "echo 'compress me' > original.txt"],
          ["/bin/bash", "-c", "cp original.txt original_copy.txt"],
          ["/bin/gzip", "original.txt"],
          ["/bin/bash", "-c", "test -f original.txt.gz"], # verify .gz exists
          ["/bin/gunzip", "original.txt.gz"],
          ["/bin/diff", "-q", "original.txt", "original_copy.txt"], # verify roundtrip
        ],
      } | Test,
  },
} | BuildSpec
