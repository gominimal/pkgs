let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in

let bash = import "../bash/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let expat = import "../expat/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "3.14.4" in
{
  name = "python",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Python-%{version}.tar.xz",
      sha256 = "d923c51303e38e249136fc1bdf3568d56ecb03214efdef48516176d3d7faaef8"
    } | Source,
    base,
    make,
    gdbm,
    ncurses,
    pkgconf,
    sqlite,
    toolchain,
    util-linux,
  ],
  runtime_deps = [
    bash,
    libffi,
    expat,
    openssl,
    glibc,
    zlib,
    subsetOf util-linux ["libuuid"],
    xz,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    # Wildcards avoid coupling to a specific python minor version. Future
    # bumps (3.14 → 3.15 → ...) don't require touching this file — the
    # `python3.*` patterns match whichever minor is installed.
    python3 = { glob = "usr/bin/python3" } | OutputBin,
    python3_minor = { glob = "usr/bin/python3.*" } | OutputBin,
    pip3 = { glob = "usr/bin/pip3" } | OutputBin,
    pip3_minor = { glob = "usr/bin/pip3.*" } | OutputBin,
    pydoc3 = { glob = "usr/bin/pydoc3" } | OutputBin,
    pydoc3_minor = { glob = "usr/bin/pydoc3.*" } | OutputBin,
    python3-config = { glob = "usr/bin/python3-config" } | OutputBin,
    python3_minor-config = { glob = "usr/bin/python3.*-config" } | OutputBin,

    libs = { glob = "usr/lib/libpython*.so*" } | OutputLib,
    datas = { glob = "usr/lib/python*/**", allow_executable = true } | OutputData,

    includes = { glob = "usr/include/python*/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "python",
        repo = "cpython",
      },
    } | Attrs,

  tests = {
    smoketest_output =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'print(\"Hello Python\")' > script.py"],
          ["/bin/python3", "script.py"],
          ["/bin/bash", "-c", "python3 script.py > output.txt"],
          ["/bin/bash", "-c", "grep -q '^Hello Python$' output.txt"],
        ],
      } | Test,

    smoketest_math =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'print(2 + 2)' > math.py"],
          ["/bin/bash", "-c", "python3 math.py | grep -q '^4$'"],
          ["/bin/bash", "-c", "echo 'print(10 * 5)' > multiply.py"],
          ["/bin/bash", "-c", "python3 multiply.py | grep -q '^50$'"],
        ],
      } | Test,

    smoketest_imports =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cat > mymodule.py << 'EOF'\ndef greet(name):\n    return f\"Hello, {name}\"\nEOF"],
          ["/bin/bash", "-c", "cat > use_module.py << 'EOF'\nimport mymodule\nprint(mymodule.greet(\"World\"))\nEOF"],
          ["/bin/bash", "-c", "python3 use_module.py | grep -q '^Hello, World$'"],
        ],
      } | Test,
  },
} | BuildSpec
