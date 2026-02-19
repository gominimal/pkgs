let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let icu = import "../icu/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.15.1" in
{
  name = "libxml2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/GNOME/libxml2/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "23b1ebd74cc562cd592cd2618c2bd88dc06fa0dfdbcd56e03cb26d6ff6b7e373",
      extract = true,
      strip_prefix = "libxml2-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
    pkgconf,
    icu,
    xz,
    zlib,
  ],
  runtime_deps = [
    glibc,
    icu,
    xz,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    xmllint = { glob = "usr/bin/xmllint" } | OutputBin,
    xmlcatalog = { glob = "usr/bin/xmlcatalog" } | OutputBin,

    libs = { glob = "usr/lib/libxml2.so*" } | OutputLib,
    includes = { glob = "usr/include/libxml2/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libxml-2.0.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/libxml2/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libxml2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "GNOME",
        repo = "libxml2",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/xmllint --version",

    parse_xml =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '<root><item>hello</item></root>' > test.xml"],
          ["/bin/bash", "-c", "xmllint --xpath '/root/item/text()' test.xml | grep -q 'hello'"],
        ],
      } | Test,
  },
} | BuildSpec
