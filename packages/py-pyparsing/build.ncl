let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let python = import "../python/build.ncl" in
let flit-core = import "../flit-core/build.ncl" in

# Pure-Python PEG parser library. cvc5 needs it at BUILD time: its rewrite-rule
# DSL compiler (src/rewriter/rw_parser.py) is written against pyparsing, and
# CMake refuses to configure without it (check_python_module("pyparsing")).
let version = "3.3.3" in
{
  name = "py-pyparsing",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/source/p/pyparsing/pyparsing-%{version}.tar.gz",
      sha256 = "928ae7e20211f3b6f3915a72f06a0cfd29ab9d24279dd6346b6b1a7146397d36",
      extract = true,
      strip_prefix = "pyparsing-%{version}",
    } | Source,
    base,
    # PEP 517 backend (`flit_core >=3.12,<5`); build-only.
    flit-core,
  ],

  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/pyparsing/**" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/pyparsing-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pyparsing",
        repo = "pyparsing",
      },
    } | Attrs,

  tests = {
    parse =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["python3", "-c", "import pyparsing as pp; r = (pp.Word(pp.alphas) + pp.Word(pp.nums)).parse_string('abc 42'); assert list(r) == ['abc', '42'], r; print(pp.__version__)"],
        ],
      } | Test,
  },
} | BuildSpec
