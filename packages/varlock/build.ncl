let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# TODO: build rather than fetch
#
# Re-onboarded 0.2.3 -> 1.17.0: the 0.x -> 1.x jump changed the packaging, so
# this is not a plain version bump. Three things moved:
#  - upstream dropped the version from the asset filename
#    (varlock-linux-x64-0.2.3.tar.gz -> varlock-linux-x64.tar.gz);
#  - the tarball now bundles a `varlock-local-encrypt` native helper next to the
#    main binary (varlock invokes it by name for the local-encrypt feature);
#  - `varlock` is now a ~104MB dynamically-linked node/bun single-executable, so
#    it needs the glibc loader + libc/libm/libdl/libpthread at runtime (0.2.3
#    declared no runtime_deps).
# Source points at the upstream release asset directly (like ghidra) rather than
# a gs:// mirror — acceptable for this low-churn, no-CVE package.
let version = "1.23.0" in
{
  name = "varlock",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/dmno-dev/varlock/releases/download/varlock%40%{version}/varlock-linux-x64.tar.gz",
          sha256 = "a40d86ceddde2f032cd8bdc594feca74f60754d01615c1a11031c9f4ca97e8ed",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/dmno-dev/varlock/releases/download/varlock%40%{version}/varlock-linux-arm64.tar.gz",
          sha256 = "7b574b420a6ae024f3cc63b944d5586ee5bdeb0e69e4945bc3e10c688d1f26a4",
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    varlock = { glob = "usr/bin/varlock" } | OutputBin,
    # The bundled native helper varlock invokes (by name) for local-encrypt.
    varlock-local-encrypt = { glob = "usr/bin/varlock-local-encrypt" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dmno-dev",
        repo = "varlock",
      },
    } | Attrs,

  tests = {
    # `standaloneTest` runs the ELF directly with no loader in the sandbox, which
    # ENOENTs for a dynamically-linked binary. Use base (bash + glibc loader) as
    # a test dep and exercise real subcommands.
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "varlock --version | grep -q '%{version}'"],
          ["/bin/bash", "-c", "varlock --help"],
        ],
      }
        | Test,
  },
} | BuildSpec
