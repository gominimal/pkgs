let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let go = import "../go/build.ncl" in
let version = "3.29.0" in
{
  name = "vale",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vale-cli/vale/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "68bbb94af847e32bc14725e61cf0b5319521960cce6f70c2a21872e9a903e9aa",
      extract = true,
      strip_prefix = "vale-%{version}",
    } | Source,
    base,
    go,
  ],
  # Go modules are fetched during the build.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  build_args = { include version },
  outputs = {
    vale = { glob = "usr/bin/vale" } | OutputBin,
  },
  # Static binary (CGO_ENABLED=0), but `vale sync` fetches style packages over HTTPS and
  # Go reads the system trust store from /etc/ssl/certs.
  runtime_deps = [ca-certificates],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "vale-cli", repo = "vale" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["vale", "--version"]],
      } | Test,
  },
} | BuildSpec
