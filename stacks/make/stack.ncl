let { stack, .. } = import "minimal.ncl" in
stack {
  name = "make",

  build_packages = ["make", "gcc", "binutils", "autoconf", "automake", "libtool", "m4", "pkgconf", "linux_headers", "base"],
  build_env_vars = {
    CC = "gcc",
    CXX = "g++",
    # glibc 2.43 implements ISO C23 const-preserving string macros: strchr,
    # strrchr, strstr, memchr, etc. now return a `const char *` for a
    # `const char *` argument. Pre-C23 code that assigns the result to a plain
    # `char *` then trips -Werror=discarded-qualifiers and FTBFS. This is an
    # ecosystem-wide wave (openssl, libxcrypt, grub, ...), not a one-off, so
    # downgrade ONLY that one warning fleet-wide for every make/autotools
    # build. It lands after each package's own -Werror on the compile line, so
    # the later flag wins. Interim: gcc-16 fixes this upstream (clean follow-up
    # is a gcc-16 bump, after which this can be dropped).
    # Ref: https://lists.gnu.org/archive/html/info-gnu/2026-01/msg00005.html
    CFLAGS = "-O2 -pipe -gno-record-gcc-switches -Wno-error=discarded-qualifiers",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/bash -c "set -ex; if [ -f configure ]; then ./configure; fi; make -j$(nproc)"'
    "%
  ],

  matches_project_if_any = [
    {
      file_regexes."Makefile" = "*",
    },
    {
      file_regexes."GNUmakefile" = "*",
    },
  ],
}
