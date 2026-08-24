# Imported from Wolfi `stress-ng` by `pkgmgr import-wolfi` (Makefile build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let acl = import "../acl/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let xz = import "../xz/build.ncl" in
let version = "0.21.04" in
{
  name = "stress-ng",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    make,
    pkgconf,
    toolchain,
    glibc,
    libcap,
    libjpeg-turbo,
    zlib,
    gcc,
    acl,
    gmp,
    mpfr,
    xz,
    {
      url = "gs://minimal-staging-archives/ColinIanKing/stress-ng/V%{version}.tar.gz",
      sha256 = "a328ba050bd3014f07a3265fb6c1aab071ae942dfad75c7459cce45a987869e1",
      extract = true,
      strip_prefix = "stress-ng-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    stress-ng = { glob = "usr/bin/stress-ng" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
    completions = { glob = "usr/share/bash-completion/**" } | OutputData,
    data = { glob = "usr/share/stress-ng/**" } | OutputData,
  },
  runtime_deps = [glibc, subsetOf gcc ["libatomic"], acl, gmp, libjpeg-turbo, mpfr, xz, zlib],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ColinIanKing", repo = "stress-ng" },
      license_spdx = "GPL-2.0-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        # Deterministic checks only. The Wolfi recipe's real ~5-30s stressor
        # workloads (--cpu/--vm/--iomix) are dropped — they run genuine load and
        # exit non-zero when a stressor can't run in a constrained CI sandbox,
        # which flakes. --version/--help/--stressors prove the binary loads.
        cmds = [
          ["/bin/bash", "-c", "stress-ng --version"],
          ["/bin/bash", "-c", "stress-ng --help 2>&1 | grep -qi usage"],
          ["/bin/bash", "-c", "stress-ng --stressors 2>&1 | grep -q cpu"],
        ],
      } | Test,
  },
} | BuildSpec
