let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "2.22.0" in
{
  name = "dotenvx",
  build_deps = [
    { file = "build.sh" } | Local,
    # Pinned release tarballs instead of piping dotenvx.sh/install.sh into a
    # shell: that fetched an unverified script AND an unverified binary at build
    # time, so the build was neither reproducible nor integrity-checked — a poor
    # property for a secrets-management tool. sha256s are upstream's own, from
    # the release's checksums.txt.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/dotenvx/dotenvx/releases/download/v%{version}/dotenvx-%{version}-linux-x86_64.tar.gz",
          sha256 = "444e32d1a5227246cba3f60cb419c5a8fd3024c6aac839a3fb9b429f72244c72",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/dotenvx/dotenvx/releases/download/v%{version}/dotenvx-%{version}-linux-aarch64.tar.gz",
          sha256 = "22fdc84e6968483a196e62353229cbbcc6b8a8892618b96acb75a7716cc1917a",
          extract = true,
        } | Source,
    } target,
    base,
    tar,
  ],
  # Intentionally empty: the release binary is static-pie linked (verified with
  # `file` on the upstream tarball), so it has no shared-library dependencies —
  # not even glibc. Do NOT "fix" this by adding one.
  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    dotenvx = { glob = "usr/bin/dotenvx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dotenvx",
        repo = "dotenvx",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/dotenvx --version",
    run =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'HELLO=World' > .env"],
          ["/bin/bash", "-c", "/bin/dotenvx run -- /bin/bash -c 'echo $HELLO' | grep -q '^World$'"],
        ],
      } | Test,
  },
} | BuildSpec
