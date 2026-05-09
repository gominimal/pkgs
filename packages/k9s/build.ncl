let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.50.18" in
{
  name = "k9s",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/derailed/k9s/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4a438b4bc480c05ba6f78a1573ee7e1dad7956ef3e30912ae22c744cea031f96",
      extract = true,
      strip_prefix = "k9s-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    k9s = { glob = "usr/bin/k9s" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["k9s", "version", "--short"]],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "derailed",
        repo = "k9s",
      },
      env_dir_mappings = [
        { read_only = false, path = "~/.kube", class = 'Credential },
        { read_only = false, path = "~/.config/k9s", class = 'Credential },
      ],
      env_file_mappings = [
        { read_only = false, path = "~/.kubeconfig", class = 'Credential },
      ],
    } | Attrs,
} | BuildSpec
