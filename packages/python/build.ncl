let { Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let expat = import "../expat/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "3.13.7" in
{
  name = "python",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Python-%{version}.tar.xz",
      sha256 = "5462f9099dfd30e238def83c71d91897d8caa5ff6ebc7a50f14d4802cdaaa79a"
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
    libffi,
    expat,
    openssl,
    glibc,
    util-linux, # TODO: Use subsets to get just libuuid
    zlib,
    xz,
  ],

  cmd = "./build.sh",
  outputs = {
    usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
    usr_include = { glob = "usr/include/**/*" } | OutputLib,
    usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
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
