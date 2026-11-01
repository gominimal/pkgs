let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in

# TODO: When packaging i see errors like: /usr/bin/bison: m4 subprocess failed: No such file or directory
# Maybe m4 needs to be a runtime_dep here?
let base = import "../base/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.8.2" in
{
  name = "bison",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/bison-%{version}.tar.xz",
      sha256 = "9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2"
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    flex,
    m4,
    toolchain,
  ],
  runtime_deps = [
    bash, # yacc is a shell script
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bison = { glob = "usr/bin/bison" } | OutputBin,
    yacc = { glob = "usr/bin/yacc" } | OutputBin,

    liby = { glob = "usr/lib/liby.a" } | OutputLib,

    bison_share = { glob = "usr/share/bison/**/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "bison (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/248a8df2ab3cc5a1fdce79b40b210b59c5591ab43df6d2111eeed879af9f3bb5/bison-x86_64.tar.zst",
              sha256 = "248a8df2ab3cc5a1fdce79b40b210b59c5591ab43df6d2111eeed879af9f3bb5",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/c0fca9123ed7c5abd41decb959ed3ca2552d0ab4e75f015c9b3dd630f63b3b11/bison-aarch64.tar.zst",
              sha256 = "c0fca9123ed7c5abd41decb959ed3ca2552d0ab4e75f015c9b3dd630f63b3b11",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "bison",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/bison --version",
  },
} | BuildSpec
