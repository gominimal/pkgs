let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14" in
{
  name = "gzip",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gzip-%{version}.tar.xz",
      sha256 = "01a7b881bd220bfdf615f97b8718f80bdfd3f6add385b993dcf6efd14e8c0ac6"
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
              url = "gs://minimal-staging-archives/prebuilts/gzip/578900779b149d12ff6b3268c3b473bb5d297b4f37d5730f821eccf22c5a7520.tar.zst",
              sha256 = "98aaf741d11c4edea8f53ac6c10d774dcce1fa524e64deb22affb72bb832ca81",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gzip/arm64-linux-gnu/gzip_1.14_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "a1c1676a373b3819cb6a0481bd93c69b0570e09495f2e23622a8e0536f74b42d",
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
