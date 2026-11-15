let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in

let version = "2.18.0" in
{
  name = "bash-completions",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/scop/bash-completion/releases/download/%{version}/bash-completion-%{version}.tar.xz",
      sha256 = "88bcf85124f77f74f2f2f8bcd16ac4382d807a827ede742a64940c7116aea33f",
    } | Source,
    base,
    make,
    tar,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    etcs = { glob = "etc/**" } | OutputData,

    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "scop",
        repo = "bash-completion",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              test -s /usr/share/bash-completion/bash_completion
              /usr/bin/bash -O extglob -n /usr/share/bash-completion/bash_completion
              n=0; for f in /usr/share/bash-completion/completions/* /usr/share/bash-completion/completions-core/*; do test -e "$f" && n=$((n+1)); done; [ $n -gt 100 ]
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
