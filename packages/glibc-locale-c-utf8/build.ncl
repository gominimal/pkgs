let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# The C.UTF-8 locale. Minimal sessions run with LANG=C.UTF-8, but the glibc
# package's locale-archive only carries en_US, so setlocale(LC_ALL, "") fails
# and anything that checks it breaks. The visible case is PostgreSQL's
# `initdb`, which refuses with "invalid locale settings; check LANG and LC_*".
# Shipped as a separate directory-form locale (the same layout Debian uses for
# C.utf8) so adding it does not rebuild glibc and everything above it. The
# compiled locale format is tied to the glibc version, so this rebuilds
# whenever glibc does.
#
# TODO: fold `localedef -i C -f UTF-8 C.UTF-8` into glibc's own build.sh the
# next time glibc is rebuilt for other reasons, then retire this package.
{
  name = "glibc-locale-c-utf8",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    glibc,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    locale = { glob = "usr/lib/locale/C.utf8/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = glibc.attrs.upstream_version,
      license_spdx = "(GPL-2.0-only AND LGPL-2.1-only)",
    } | Attrs,
  tests = {
    # `locale` warns on stderr when LANG names a locale that cannot be loaded.
    c_utf8_loads =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "out=$(LANG=C.UTF-8 LC_ALL= locale 2>&1 >/dev/null); [ -z \"$out\" ] || { echo \"$out\" >&2; exit 1; }; LC_ALL=C.UTF-8 locale charmap | grep -qx UTF-8"],
        ],
      } | Test,
  },
} | BuildSpec
