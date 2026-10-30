let { BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

# Build-time helper for node and node-lts: rebuilds undici's llhttp wasm from its
# in-tree C and splices it over the shipped base64 blobs. See the script's docstring.
{
  name = "llhttp-wasm-rebuild",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "rebuild-llhttp-wasm.py" } | Local,
    base,
    python, # build.sh runs the selftest
  ],
  # node, node-lts and next run the installed script with python3
  runtime_deps = [python],
  cmd = "./build.sh",
  outputs = {
    script = { glob = "usr/share/llhttp-wasm-rebuild/rebuild-llhttp-wasm.py" } | OutputData,
  },
  tests = {
    selftest =
      {
        class = 'Standalone,
        test_deps = [python],
        cmds = [["python3", "/usr/share/llhttp-wasm-rebuild/rebuild-llhttp-wasm.py", "selftest"]],
      } | Test,
  },
} | BuildSpec
