let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libxml2 = import "../libxml2/build.ncl" in

let version = "1.1.45" in
{
  name = "libxslt",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/GNOME/libxslt/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "023900618fbf789dba364f38f184a0fe2d3ebad2b2ab06003ffd2d1ee2d5461c",
      extract = true,
      strip_prefix = "libxslt-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
    pkgconf,
    libxml2,
  ],
  runtime_deps = [
    glibc,
    libxml2,
  ],

  cmd = "./build.sh",

  outputs = {
    xsltproc = { glob = "usr/bin/xsltproc" } | OutputBin,

    libxslt = { glob = "usr/lib/libxslt.so*" } | OutputLib,
    libexslt = { glob = "usr/lib/libexslt.so*" } | OutputLib,
    includes = { glob = "usr/include/libxslt/**" } | OutputData,
    includes_exslt = { glob = "usr/include/libexslt/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libxslt.pc" } | OutputData,
    pkgconfig_exslt = { glob = "usr/lib/pkgconfig/libexslt.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libxslt",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/xsltproc --version",

    transform =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '<?xml version=\"1.0\"?><data><val>42</val></data>' > input.xml"],
          ["/bin/bash", "-c", "echo '<?xml version=\"1.0\"?><xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\"><xsl:template match=\"/\"><out><xsl:value-of select=\"data/val\"/></out></xsl:template></xsl:stylesheet>' > style.xsl"],
          ["/bin/bash", "-c", "xsltproc style.xsl input.xml | grep -q '42'"],
        ],
      } | Test,
  },
} | BuildSpec
