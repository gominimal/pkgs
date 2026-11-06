let { BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
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
              [[ $(< /etc/resolv.conf) == *'nameserver 8.8.8.8'* ]]
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
