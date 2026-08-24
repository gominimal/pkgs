let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "23.7" in
{
  name = "psmisc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.sourceforge.net/project/psmisc/psmisc/psmisc-%{version}.tar.xz",
      sha256 = "58c55d9c1402474065adae669511c191de374b0871eec781239ab400b907c327",
      extract = true,
      strip_prefix = "psmisc-%{version}",
    } | Source,
    base,
    make,
    ncurses,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    ncurses,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  tests = {
    smoketest = standaloneTest "/bin/killall --version",
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'Gitlab,
      host = "gitlab.com",
      owner = "psmisc",
      repo = "psmisc",
    },
    license_spdx = "GPL-2.0-or-later",
  },
} | BuildSpec
