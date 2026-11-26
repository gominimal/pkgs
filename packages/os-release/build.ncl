let { BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "os-release",
  # No `base` here: `base` carries os-release at runtime, so building against it would be a cycle.
  build_deps = [
    { file = "build.sh" } | Local,
    bash-bootstrap,
    coreutils,
  ],

  cmd = "./build.sh",

  outputs = {
    # The vendor file, and the /etc symlink to it (os-release(5)).
    os_release = { glob = "usr/lib/os-release" } | OutputData,
    os_release_etc = { glob = "etc/os-release" } | OutputData,
  },

  tests = {
    identifies_minimal =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "for f in /etc/os-release /usr/lib/os-release; do (. \"$f\" && test \"$ID\" = minimal && test \"$NAME\" = Minimal) || exit 1; done"],
        ],
      } | Test,
  },
} | BuildSpec
