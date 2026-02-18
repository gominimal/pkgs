let { harness, .. } = import "minimal.ncl" in
harness {
  name = "make",

  build_packages = ["make", "gcc", "binutils", "autoconf", "automake", "libtool", "m4", "pkgconf", "linux_headers", "base"],
  build_env_vars = {
    CC = "gcc",
    CXX = "g++",
    CFLAGS = "-O2 -pipe",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/bash -c "set -ex; if [ -f configure ]; then ./configure; fi; make -j$(nproc)"'
    "%
  ],

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes."Makefile" = "*",
    },
    {
      file_regexes."GNUmakefile" = "*",
    },
  ],
}
