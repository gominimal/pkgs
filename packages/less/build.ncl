let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "704" in
{
  name = "less",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://www.greenwoodsoftware.com/less/less-704.tar.gz
      url = "gs://minimal-staging-archives/less-%{version}.tar.gz",
      sha256 = "20a0b0a2bb2525fa53c7eee9beb854b4c9cf172eabb209af7020743547bfe9fb"
    } | Source,
    base,
    make,
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
    less = { glob = "usr/bin/less" } | OutputBin,
    # lessecho MOVED in 704: upstream's Makefile.in installs it to
    # ${libexecdir} where 692 installed it to ${bindir} —
    #   692:  ${INSTALL_PROGRAM} lessecho ${DESTDIR}${bindir}/lessecho
    #   704:  ${INSTALL_PROGRAM} lessecho ${DESTDIR}${libexecdir}/lessecho
    # so with --prefix=/usr it lands in usr/libexec, and the old usr/bin glob
    # matched nothing ("output globs did not match any files: lessecho").
    #
    # Following upstream rather than forcing --libexecdir=/usr/bin: lessecho is
    # an internal helper for LESSOPEN pipes, not a user-facing command, and 24
    # packages here already ship usr/libexec outputs while none override
    # libexecdir. OutputLib matches findutils' `libexec_frcode`, the same shape
    # — an executable helper that lives outside PATH.
    lessecho = { glob = "usr/libexec/lessecho" } | OutputLib,
    lesskey = { glob = "usr/bin/lesskey" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "gwsw",
        repo = "less",
      },
      license_spdx = "BSD-2-Clause OR GPL-3.0-or-later",
      # Home page: https://www.greenwoodsoftware.com/less/
    } | Attrs,
} | BuildSpec
