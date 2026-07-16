let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.11.0" in
{
  name = "shellcheck",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/koalaman/shellcheck/releases/download/v%{version}/shellcheck-v%{version}.linux.x86_64.tar.xz",
          sha256 = "8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/koalaman/shellcheck/releases/download/v%{version}/shellcheck-v%{version}.linux.aarch64.tar.xz",
          sha256 = "12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588",
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    shellcheck = { glob = "usr/bin/shellcheck" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "koalaman",
        repo = "shellcheck",
      },
    } | Attrs,
} | BuildSpec
