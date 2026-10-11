let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let bash = import "../bash/build.ncl" in

# direnv: loads and unloads per-directory environment (.envrc) as you cd.
# Evaluates every .envrc with bash, so bash is a runtime dep and its path is
# baked in (DIRENV_BASH still overrides).
let version = "2.38.1" in
{
  name = "direnv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/direnv/direnv/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "3bd0d49c163204543db8f22f55af8985121db24fe6b21c5b749695e4fbdbb1fe",
      extract = true,
      strip_prefix = "direnv-%{version}",
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
    direnv = { glob = "usr/bin/direnv" } | OutputBin,
  },
  runtime_deps = [bash],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "direnv", repo = "direnv" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    # Loads an allowed .envrc and exports its variable.
    envrc =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "direnv version | grep -qx %{version} && d=$(mktemp -d) && cd \"$d\" && export HOME=$d XDG_CONFIG_HOME=$d/c XDG_DATA_HOME=$d/d && echo 'export DIRENV_SMOKE=ok' > .envrc && direnv allow . && test \"$(direnv exec . sh -c 'echo $DIRENV_SMOKE')\" = ok"],
        ],
      } | Test,
  },
} | BuildSpec
