let { harness, .. } = import "minimal.ncl" in
harness {
  name = "meson",

  build_packages = ["meson", "ninja", "gcc", "binutils", "pkgconf", "linux_headers", "python", "base"],
  build_env_vars = {
    CC = "gcc",
    CXX = "g++",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/bash -c "set -ex; meson setup build --buildtype=release; ninja -C build"'
    "%
  ],
}
