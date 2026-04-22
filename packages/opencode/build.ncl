let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14.20" in
{
  name = "opencode",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/sst/opencode/releases/download/v%{version}/opencode-linux-x64.tar.gz",
          sha256 = "1707133022382ea8c8cc5bc47ab1db52fa206bd9baf8d3ad4d862b489dbb448f",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/sst/opencode/releases/download/v%{version}/opencode-linux-arm64.tar.gz",
          sha256 = "3ca509044e06b8e7dacf08de735addee400788f80729c333fbf4581d0f77b4d3",
          extract = true,
        } | Source,
    } target,
    base,
  ],

  runtime_deps = [
    glibc,
    git,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    opencode = { glob = "usr/bin/opencode" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "sst",
        repo = "opencode",
      },
      env_dir_mappings = [
        { read_only = false, path = "~/.local/share/opencode", class = 'State },
        { read_only = false, path = "~/.config/opencode", class = 'State },
      ],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/opencode --version",
  },
} | BuildSpec
