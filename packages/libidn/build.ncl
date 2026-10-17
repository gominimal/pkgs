let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let glibc-locale-c-utf8 = import "../glibc-locale-c-utf8/build.ncl" in

# GNU libidn 1.x (IDNA2003), the predecessor of libidn2. Still what some
# bindings link against, e.g. the idn-ruby gem (used by Mastodon and other
# Rails apps), which will not build against libidn2.
let version = "1.44" in
{
  name = "libidn",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ftpmirror.gnu.org/libidn/libidn-%{version}.tar.gz",
      sha256 = "499608bab3a65650a0ea52888c13a8deebe3f71408e319acd9ec52e02eb13959",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    idn = { glob = "usr/bin/idn" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
    emacs = { glob = "usr/share/emacs/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # Library: LGPL-3.0+ or GPL-2.0+; the idn tool and the rest: GPL-3.0+.
      license_spdx = "GPL-3.0-or-later AND (GPL-2.0-or-later OR LGPL-3.0-or-later)",
      source_provenance = {
        category = 'GnuProject,
        name = "libidn",
      },
    } | Attrs,
  tests = {
    # IDNA ToASCII of a non-ASCII label.
    to_ascii =
      {
        class = 'Standalone,
        test_deps = [base, glibc-locale-c-utf8],
        cmds = [
          ["/bin/bash", "-c", "test \"$(printf 'b\\303\\274cher.example' | LC_ALL=C.UTF-8 /bin/idn --quiet --idna-to-ascii)\" = xn--bcher-kva.example"],
        ],
      } | Test,
  },
} | BuildSpec
