let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let go = import "../go/build.ncl" in

let version = "1.37.3" in

{
  name = "kubectl",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/kubernetes/kubernetes/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e855a5151a209537df57e10c13eb07ab164e2fc50137a6649e99e5366bc0bb57",
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
