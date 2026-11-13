let { BuildSpec, .. } = import "minimal.ncl" in
let jdk-25 = import "../jdk-25/build.ncl" in
# `jdk` is the CURRENT Java LTS: a meta-package over the versioned line
# (same shape as `toolchain`). Projects that need a specific line depend on
# jdk-21 / jdk-25 / jdk-27 directly; when the next LTS lands, this one moves.
{
  name = "jdk",
  build_deps = [],
  runtime_deps = [
    jdk-25,
  ],
  cmd = "",
  outputs = {},
} | BuildSpec
