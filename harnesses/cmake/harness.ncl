let { harness, .. } = import "minimal.ncl" in
harness {
  name = "cmake",

  build_packages = ["cmake", "make", "gcc", "binutils", "pkgconf", "linux_headers", "base"],
  build_env_vars = {
    CC = "gcc",
    CXX = "g++",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/bash -c "set -ex; cmake -B build .; cmake --build build -j$(nproc)"'
    "%
  ],

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes."CMakeLists.txt" = "*",
    },
  ],
}
