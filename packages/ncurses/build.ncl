let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let attr = import "../attr/build.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "6.6" in
{
  name = "ncurses",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ncurses-%{version}.tgz",
      sha256 = "355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    attr,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    # ncursesw6-config needs /bin/sh
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,

    libform = { glob = "usr/lib/libform*.so*" } | OutputLib,
    libncurses = { glob = "usr/lib/libncurses*.so*" } | OutputLib,
    libmenu = { glob = "usr/lib/libmenu*.so*" } | OutputLib,
    libpanel = { glob = "usr/lib/libpanel*.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    tabset = { glob = "usr/share/tabset/*" } | OutputData,

    terminfo = { glob = "usr/{lib,share}/terminfo/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "X11-distribute-modifications-variant",
      source_provenance = {
        category = 'GnuProject,
        name = "ncurses",
      },
    } | Attrs,
} | BuildSpec
