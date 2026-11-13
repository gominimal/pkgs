let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# SymFPU: header-only C++ templates implementing the SMT-LIB floating-point
# theory in terms of bit-vectors. cvc5 bit-blasts FP through it, and since
# 1.4.0 refuses anything older than 1.2.0 (it probes for
# `unpackedFloat<t>::makeOne()`, cvc5#12662 / #12958). Upstream tags each
# release as `symfpu-<v>-dual-license`; cvc5 1.4.2 pins this exact commit
# (40bdec00e99f8ea1b96c3dac0a05eed11c541639).
let version = "1.2.0" in
{
  name = "symfpu",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/martin-cs/symfpu/archive/refs/tags/symfpu-%{version}-dual-license.tar.gz",
      sha256 = "0026c726b52e795d5732c642f0a78b0ec005fd070ba2fa6ca47ade311d37e28c",
      extract = true,
      strip_prefix = "symfpu-symfpu-%{version}-dual-license",
    } | Source,
    base,
  ],
  runtime_deps = [],

  cmd = "./build.sh",

  outputs = {
    # The include layout cvc5 (and its FindSymFPU.cmake) expects:
    # <prefix>/include/symfpu/{core,utils}/*.h
    includes = { glob = "usr/include/symfpu/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # The user's choice of BSD-3-Clause or GPL-3.0 (LICENSE, LICENSE-BSD,
      # LICENSE-GPL3); cvc5 takes it under BSD-3-Clause.
      license_spdx = "BSD-3-Clause OR GPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "martin-cs",
        repo = "symfpu",
      },
    } | Attrs,

  tests = {
    # Header-only: prove the headers are where consumers look and that they
    # parse as C++ (the include graph is self-contained apart from the traits
    # a back end supplies).
    headers =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/include/symfpu/core/unpackedFloat.h && test -f /usr/include/symfpu/utils/common.h"],
          ["/bin/bash", "-c", "printf '#include <symfpu/core/unpackedFloat.h>\\nint main(){return 0;}\\n' > /tmp/t.cpp && g++ -std=c++17 -fsyntax-only /tmp/t.cpp"],
        ],
      } | Test,
  },
} | BuildSpec
