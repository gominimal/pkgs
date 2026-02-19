let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let attr = import "../attr/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "6.5-20250830" in
{
  name = "ncurses",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ncurses-%{version}.tgz",
      sha256 = "519ec9f748d7f2873cf763394fc766a701967439610125ad0fbf76ab2c7510a5"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    attr,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

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
      source_provenance = {
        category = 'GnuProject,
        name = "ncurses",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "ncurses (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/ncurses/bd06d23c33d5bae4467bf46e0fa31863d27972af520621c0007e02eac95002e6.tar.zst",
              sha256 = "a0c8f8ba43f78f71526c1b3fdccf065cab3a6f3bb55ee271c53733f1c480f5f7",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/ncurses/arm64-linux-gnu/ncurses_6.5_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "5a03e782caaa01afff641563760bf8cfe1da0e6342f8ab8a5326dcf44f7d05df",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        attr,
      ],
      outputs = {
        bin = { glob = "usr/bin/*" } | OutputBin,
        form_lib = { glob = "usr/lib/libform*.so*" } | OutputLib,
        includes = { glob = "usr/include/**" } | OutputData,
        libraries = { glob = "usr/lib/libncurses*.so*" } | OutputLib,
        menu_lib = { glob = "usr/lib/libmenu*.so*" } | OutputLib,
        panel_lib = { glob = "usr/lib/libpanel*.so*" } | OutputLib,
        pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
        tabset = { glob = "usr/share/tabset/*" } | OutputData,
        terminfo_lib = { glob = "usr/lib/terminfo/**/*" } | OutputLib,
        terminfo_share = { glob = "usr/share/terminfo/**/*" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
