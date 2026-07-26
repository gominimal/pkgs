let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let go = import "../go/build.ncl" in

let version = "1.36.3" in

{
  name = "kubectl",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/kubernetes/kubernetes/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "950f7dd65b64b18ca065a08ae73dd5f61ff72b48c8778c5bfceacc84eaaf10ed",
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
