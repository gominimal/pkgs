let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let go = import "../go/build.ncl" in

let version = "1.36.0" in

{
  name = "kubectl",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/kubernetes/kubernetes/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "b98652d8ebf5d60d0715cd952e5d489aa10e14ad75d7b6e2425b8de8c65aa4c5",
      extract = true,
      strip_prefix = "kubernetes-%{version}",
    } | Source,
    bash,
    go,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    kubectl = { glob = "usr/bin/kubectl" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["kubectl", "version", "--client"]],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "kubernetes",
        repo = "kubernetes",
      },
      env_dir_mappings = [{ read_only = false, path = "~/.kube", class = 'Credential }, { read_only = false, path = "~/.minikube", class = 'Credential }],
      env_file_mappings = [{ read_only = false, path = "~/.kubeconfig", class = 'Credential }],
    } | Attrs,
} | BuildSpec
