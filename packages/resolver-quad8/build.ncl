let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "resolver-quad8",
  build_deps = [
    { file = "build.sh" } | Local,
    bash,
    coreutils,
  ],
  cmd = "build.sh",
  outputs = {
    resolvconf = { glob = "etc/resolv.conf" } | OutputData,
  },
  # Authored in this repository, so Apache-2.0 like every recipe here
  # (LICENSING.md section 1).
  attrs = { license_spdx = "Apache-2.0" } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              # An active line naming exactly 8.8.8.8: not commented out,
              # not 8.8.8.80.
              ok=
              while read -r kw addr _; do
                [[ $kw == nameserver && $addr == 8.8.8.8 ]] && ok=1
              done < /etc/resolv.conf
              [[ -n $ok ]]
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
