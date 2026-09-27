let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "2.31.1" in
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
          sha256 = "127e951f1728ce0bc63a1da86b4c8d30c46e47f7c3a69f443ad67aa243dccc19",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/dotenvx/dotenvx/releases/download/v%{version}/dotenvx-%{version}-linux-aarch64.tar.gz",
          sha256 = "0e3882bdd3888535084aa7c2465024a8543d3b368ceea1c9088fd50ee3e776ad",
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
