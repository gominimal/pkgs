let { BuildSpec, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# node-24: the Node.js 24 line by a stable name. 24 entered maintenance on
# 2026-10-20 and is supported until 2028-04-30 (nodejs/Release schedule.json).
#
# While node-lts is on 24.x this is a meta-package over it (same shape as `jdk`
# over `jdk-25`): it builds nothing and pulls node-lts in as a runtime dep, so a
# box that lists node-24 gets node-lts's /usr/bin/{node,npm,npx},
# /usr/lib/node_modules and /usr/include/node. Building node-24 separately
# compiled V8 a second time for the same release, and its copy had drifted:
# it lacked --openssl-use-def-ca-store (the system CA store, CVE-2026-111943)
# and the llhttp / amaro wasm rebuilds.
#
# The day node-lts moves off 24, this file fails to evaluate (below) instead of
# silently handing out another major. Restore node-24 as its own build then:
# copy node-lts's build.ncl and build.sh at its last 24.x release, rename it,
# and keep pkgmgr's `[node-24] series = "24"` pin (pkgmgr-rs
# data/series_pins.toml) tracking it.
let lts_version = node-lts.attrs.upstream_version in
let lts_major = std.array.first (std.string.split "." lts_version) in
if lts_major != "24" then
  std.fail_with "node-24: node-lts is %{lts_version}, not 24.x; restore node-24 as its own 24.x build (see the comment in packages/node-24/build.ncl)"
else
  {
    name = "node-24",
    build_deps = [],
    runtime_deps = [
      node-lts,
    ],
    cmd = "",
    outputs = {},

    tests = {
      # The paths consumers of node-24 relied on come through node-lts, at 24.x.
      node_24_paths =
        {
          class = 'Standalone,
          test_deps = [bash-bootstrap, coreutils, grep],
          cmds = [
            ["/bin/bash", "-c", "node -p process.versions.node | grep -q '^24\\.'"],
            ["/bin/bash", "-c", "node -e 'console.log(6 * 7)' | grep -qx 42"],
            ["/bin/bash", "-c", "npm --version | grep -qE '^[0-9]+\\.'"],
            ["/bin/bash", "-c", "npx --version | grep -qE '^[0-9]+\\.'"],
            ["/bin/bash", "-c", "test -f /usr/include/node/node.h"],
          ],
        } | Test,
    },
  } | BuildSpec
