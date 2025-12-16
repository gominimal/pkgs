let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let attr = import "../attr/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in
{
  name = "ncurses",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ncurses-6.5-20250830.tgz",
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
    bin = { glob = "usr/bin/*" } | OutputBin,
    form_lib = { glob = "usr/lib/libform*.so*" } | OutputLib,
    usr_include = { glob = "usr/include/*" } | OutputData,
    libraries = { glob = "usr/lib/libncurses*.so*" } | OutputLib,
    menu_lib = { glob = "usr/lib/libmenu*.so*" } | OutputLib,
    panel_lib = { glob = "usr/lib/libpanel*.so*" } | OutputLib,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    tabset = { glob = "usr/share/tabset/*" } | OutputData,
    terminfo_lib = { glob = "usr/lib/terminfo/**/*" } | OutputLib,
    terminfo_share = { glob = "usr/share/terminfo/**/*" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "ncurses (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/ncurses/bd06d23c33d5bae4467bf46e0fa31863d27972af520621c0007e02eac95002e6.tar.zst",
          sha256 = "a0c8f8ba43f78f71526c1b3fdccf065cab3a6f3bb55ee271c53733f1c480f5f7",
          extract = true,
        } | Source,
      ],
      runtime_deps = [
        attr,
      ],
      outputs = {
        bin = { glob = "usr/bin/*" } | OutputBin,
        form_lib = { glob = "usr/lib/libform*.so*" } | OutputLib,
        usr_include = { glob = "usr/include/*" } | OutputData,
        libraries = { glob = "usr/lib/libncurses*.so*" } | OutputLib,
        menu_lib = { glob = "usr/lib/libmenu*.so*" } | OutputLib,
        panel_lib = { glob = "usr/lib/libpanel*.so*" } | OutputLib,
        pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
        tabset = { glob = "usr/share/tabset/*" } | OutputData,
        terminfo_lib = { glob = "usr/lib/terminfo/**/*" } | OutputLib,
        terminfo_share = { glob = "usr/share/terminfo/**/*" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
