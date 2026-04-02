let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "6.12.0.199" in
{
  name = "mono",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://download.mono-project.com/sources/mono/mono-%{version}.tar.xz",
      sha256 = "c0850d545353a6ba2238d45f0914490c6a14a0017f151d3905b558f033478ef5",
    } | Source,
    autoconf,
    automake,
    base,
    cmake,
    libtool,
    make,
    perl,
    pkgconf,
    python,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/{mono,mono-sgen,mono-boehm,pedump,monow,sgen-grep-binprot,mono-hang-watchdog}" } | OutputBin,
    scripts = { glob = "usr/bin/*", allow_executable = true } | OutputData,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    mono-libs = { glob = "usr/lib/mono/**", allow_executable = true } | OutputData,
    etc = { glob = "usr/etc/mono/**" } | OutputData,
    includes = { glob = "usr/include/mono-2.0/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      build_cost_multiple = 2,
      source_provenance = {
        category = 'GithubRepo,
        owner = "mono",
        repo = "mono",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/mono", "--version"],
          ["/bin/mcs", "--version"],
        ],
      } | Test,

    compile_hello_world =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cat > hello.cs << 'EOF'\nusing System;\nclass Hello {\n    static void Main() {\n        Console.WriteLine(\"Hello Mono\");\n    }\n}\nEOF"],
          ["/bin/mcs", "hello.cs"],
          ["/bin/bash", "-c", "mono hello.exe | grep -q '^Hello Mono$'"],
        ],
      } | Test,

    compile_math =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cat > math.cs << 'EOF'\nusing System;\nclass MathTest {\n    static void Main() {\n        Console.WriteLine(2 + 2);\n        Console.WriteLine(10 * 5);\n    }\n}\nEOF"],
          ["/bin/mcs", "math.cs"],
          ["/bin/bash", "-c", "mono math.exe | head -1 | grep -q '^4$'"],
          ["/bin/bash", "-c", "mono math.exe | tail -1 | grep -q '^50$'"],
        ],
      } | Test,

    compile_with_library =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cat > mylib.cs << 'EOF'\nnamespace MyLib {\n    public class Greeter {\n        public static string Greet(string name) {\n            return \"Hello, \" + name;\n        }\n    }\n}\nEOF"],
          ["/bin/mcs", "-target:library", "mylib.cs"],
          ["/bin/bash", "-c", "cat > main.cs << 'EOF'\nusing System;\nusing MyLib;\nclass Program {\n    static void Main() {\n        Console.WriteLine(Greeter.Greet(\"World\"));\n    }\n}\nEOF"],
          ["/bin/mcs", "-r:mylib.dll", "main.cs"],
          ["/bin/bash", "-c", "mono main.exe | grep -q '^Hello, World$'"],
        ],
      } | Test,
  },
} | BuildSpec
