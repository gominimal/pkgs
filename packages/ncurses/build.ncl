let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
  attrs.upstream_version = version,

  replace_on_cycle =
    {
      name = "ncurses (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/ncurses/arm64-linux-gnu/ncurses_6.5_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "36e36ee6d034c79bd533ba27f56a44154a3da94d1c1321442872e3fd051f0f38",
          extract = true,
        } | Source,
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
