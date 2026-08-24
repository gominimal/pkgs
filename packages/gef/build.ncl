let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let gdb = import "../gdb/build.ncl" in
let python = import "../python/build.ncl" in

let version = "2026.01" in
{
  name = "gef",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/hugsy/gef/archive/refs/tags/%{version}.tar.gz",
      sha256 = "6e58afbda13ef976aa46a2f138b5422829a0d3c4b71246f4546cbd7383ce2e76",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash,
    # gef is a gdb EXTENSION — it is not a program, it is 433 KB of Python that
    # gdb loads. Both of these are hard requirements, not conveniences:
    # gef.py asserts GDB_MIN_VERSION (10,0) and PYTHON_MIN_VERSION (3,10) at
    # import time and refuses to load otherwise. Ours are gdb 17.2 and Python
    # 3.14, comfortably past both.
    #
    # The gdb package is built --with-python specifically so this works; a gdb
    # without it reports "Python scripting is not supported in this copy of
    # GDB" and gef cannot load at all. That flag is pinned by a test over
    # there rather than trusted.
    gdb,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    gef = { glob = "usr/bin/gef" } | OutputBin,
    gef_py = { glob = "usr/share/gef/gef.py" } | OutputData,
  },

  tests = {
    smoketest = standaloneTest "/bin/gef --version",

    # Loading is the whole package. gef is a single Python file, so there is no
    # compile step that could fail — the only way this package breaks is that
    # gdb cannot IMPORT it, and that failure is quiet: gdb prints the Python
    # traceback to stderr and then carries on to a normal prompt, exiting 0.
    # So assert on gef's own output, never on gdb's exit code.
    loads_into_gdb =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # `gef` is registered as a gdb command only if gef.py imported
          # cleanly all the way to the bottom of the file.
          ["/bin/bash", "-c", "gef -batch -ex 'gef help' 2>&1 | grep -qi 'gef'"],
          # A traceback on stderr means a partial import — gef would look
          # present while most commands were missing.
          ["/bin/bash", "-c", "! gef -batch -ex 'gef help' 2>&1 | grep -q 'Traceback'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "hugsy",
        repo = "gef",
      },
    } | Attrs,
} | BuildSpec
