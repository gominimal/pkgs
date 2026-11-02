let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let tmux = import "../tmux/build.ncl" in

# overmind: Procfile process manager (web + worker + css/js watchers) built
# on tmux, so each process can be attached to, restarted or debugged alone.
# Runs every process through tmux, hence the runtime dep.
let version = "2.5.1" in
{
  name = "overmind",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/DarthSim/overmind/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "d616b89465d488878ed2e1f79e66f8af5b5c2f1d3cf75c2b08e04fb04752d187",
      extract = true,
      strip_prefix = "overmind-%{version}",
    } | Source,
    base,
    go,
  ],
  # Go module downloads.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    overmind = { glob = "usr/bin/overmind" } | OutputBin,
  },
  runtime_deps = [tmux],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "DarthSim", repo = "overmind" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "overmind --version | grep -q %{version} && tmux -V"],
        ],
      } | Test,
  },
} | BuildSpec
