let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

# TODO: This doesn't install the opencv_contrib, which has a LOT of the useful stuff. Implement that.
# See:
#  - https://docs.opencv.org/4.x/db/d05/tutorial_config_reference.html
#  - https://docs.opencv.org/4.x/d7/d9f/tutorial_linux_install.html
let version = "4.12.0" in
{
  name = "opencv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/opencv/opencv/archive/refs/tags/4.12.0.tar.gz
      url = "gs://minimal-staging-archives/opencv-%{version}.tar.gz",
      sha256 = "44c106d5bb47efec04e531fd93008b3fcd1d27138985c5baf4eafac0e1ec9e9d",
      extract = true,
    } | Source,
    base,
    toolchain,
    cmake,
    make,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    "setup_vars_opencv4.sh" = { glob = "usr/bin/setup_vars_opencv4.sh" } | OutputBin,
    opencv_version = { glob = "usr/bin/opencv_version" } | OutputBin,
    opencv_interactive-calibration = { glob = "usr/bin/opencv_interactive-calibration" } | OutputBin,
    opencv_annotation = { glob = "usr/bin/opencv_annotation" } | OutputBin,
    opencv_model_diagnostics = { glob = "usr/bin/opencv_model_diagnostics" } | OutputBin,
    opencv_visualisation = { glob = "usr/bin/opencv_visualisation" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    shares = { glob = "usr/share/opencv4/**" } | OutputData,
    includes = { glob = "usr/include/opencv4/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "opencv",
        repo = "opencv",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
