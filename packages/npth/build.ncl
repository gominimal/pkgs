# npth — the New GNU Portable Threads library, gnupg's cooperative threading
# layer. The one library in gnupg's stack with no dependency on libgpg-error.
#
# Hand-written: `pkgmgr import wolfi` could not emit it (libksba's recipe has
# unmapped apk deps; npth's source is not a github URL in the recipe), but
# upstream does publish both on github.com/gpg, so the source is the same
# archive/refs/tags form as its siblings here.
#
# build.sh is libgpg-error's verbatim, including `make MAKEINFO=true` — these
# autotools trees regenerate .info docs and texinfo is not in the fleet, the
# same convention emacs/gdb/binutils-arm-none-eabi already use.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gettext = import "../gettext/build.ncl" in
let version = "1.8" in
{
  name = "npth",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    autoconf,
    automake,
    libtool,
    m4,
    make,
    pkgconf,
    toolchain,
    glibc,
    gettext,
    {
      url = "https://github.com/gpg/npth/archive/refs/tags/npth-%{version}.tar.gz",
      sha256 = "39baf403b0d63271b31a7546a480b4570a422465823f82d93bcdd9c1491df5af",
      extract = true,
      strip_prefix = "npth-npth-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [glibc, autoconf, automake, gettext, pkgconf],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "npth" },
      license_spdx = "GPL-2.0-or-later AND LGPL-2.1-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, pkgconf],
        cmds = [
          # npth ships no binaries, so the meaningful check is that the library
          # and its pkg-config metadata are usable — link a program against it.
          # (This package previously carried libgpg-error's test block verbatim,
          # which invoked gpg-error and yat2m and exited 127.)
          ["/bin/bash", "-c", "pkg-config --exists npth && pkg-config --modversion npth"],
          ["/bin/bash", "-c", "printf '#include <npth.h>\\nint main(void){ return npth_init(); }\\n' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t $(pkg-config --cflags --libs npth) && /tmp/t"],
        ],
      } | Test,
  },
} | BuildSpec
