let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let openjpeg = import "../openjpeg/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let libwebp = import "../libwebp/build.ncl" in

# TODO: This doesn't install the opencv_contrib, which has a LOT of the useful stuff. Implement that.
# See:
#  - https://docs.opencv.org/4.x/db/d05/tutorial_config_reference.html
#  - https://docs.opencv.org/4.x/d7/d9f/tutorial_linux_install.html
let version = "4.14.0" in
{
  name = "opencv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/opencv/opencv/archive/refs/tags/4.14.0.tar.gz
      url = "gs://minimal-staging-archives/opencv-%{version}.tar.gz",
      sha256 = "ee8fb9b30eb60850431b4656447080e3737b56e45719c92b67f245950609f86e",
      extract = true,
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    # The registry's image libraries, in place of opencv's bundled
    # 3rdparty/ copies. opencv looks for them at configure time and builds
    # its own copy of any it does not find; build.sh fails the build if it
    # built one. libtiff stays bundled (no package yet). See build.sh.
    zlib,
    openjpeg,
    libpng,
    libjpeg-turbo,
    libwebp,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
    # libopencv_imgcodecs NEEDs libopenjp2, libpng16, libjpeg and libwebp
    # (build.sh checks it).
    openjpeg,
    libpng,
    libjpeg-turbo,
    libwebp,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    "setup_vars_opencv4.sh" = { glob = "usr/bin/setup_vars_opencv4.sh", allow_missing_interpreter = true } | OutputBin,
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
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "opencv",
        repo = "opencv",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/opencv_version",
    # Writes and reads back PNG, JPEG and WebP through libopencv_imgcodecs,
    # that is, through the registry's libpng, libjpeg-turbo and libwebp.
    image_codecs =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
set -euo pipefail
cat > codecs.cpp <<'EOF'
#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <iostream>
#include <string>

int main() {
    cv::Mat img(48, 64, CV_8UC3);
    for (int y = 0; y < img.rows; y++)
        for (int x = 0; x < img.cols; x++)
            img.at<cv::Vec3b>(y, x) = cv::Vec3b(x * 4, y * 5, (x + y) * 2);
    const char *exts[] = {"png", "jpg", "webp"};
    for (const char *ext : exts) {
        std::string path = std::string("test.") + ext;
        if (!cv::imwrite(path, img)) { std::cerr << "imwrite failed: " << path << "\n"; return 1; }
        cv::Mat back = cv::imread(path, cv::IMREAD_COLOR);
        if (back.empty() || back.size() != img.size() || back.type() != img.type()) {
            std::cerr << "imread failed: " << path << "\n"; return 1;
        }
        double diff = cv::norm(img, back, cv::NORM_INF);
        // PNG is lossless; JPEG and lossy WebP only have to be close.
        if ((std::string(ext) == "png" && diff != 0) || diff > 64) {
            std::cerr << path << ": max pixel difference " << diff << "\n"; return 1;
        }
        std::cout << path << " ok (max diff " << diff << ")\n";
    }
    std::cout << "OK\n";
    return 0;
}
EOF
g++ codecs.cpp -o codecs -I/usr/include/opencv4 -lopencv_imgcodecs -lopencv_core
./codecs | tee out.txt
grep -qx OK out.txt
"%
          ],
        ],
      } | Test,
  },
} | BuildSpec
