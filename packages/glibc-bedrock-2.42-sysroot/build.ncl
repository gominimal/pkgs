let { subsetOf, BuildSpec, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# glibc-bedrock-2.42-sysroot: only the versioned sysroot of glibc-bedrock-2.42
# (usr/lib/glibc-bedrock-2.42/{lib,include}), for the bootstrap rungs that compile against it.
# Depending on glibc-bedrock-2.42 itself also brings its plain /usr tree: the sealed amd64 tarball
# carries a whole glibc 2.42 at /usr/lib, which collides with production glibc 2.44 path for path,
# and whichever lands first wins (pkgs#895: classpath-0.93's sort/env failed on GLIBC_2.43).
# A collection, because a subset is only supported as a runtime dep: `subsetOf` in build_deps
# panics in minimal's executor (op/src/specs.rs, `todo!("input: ...")`).
let glibc-bedrock-2-42 = import "../glibc-bedrock-2.42/build.ncl" in
match {
  { arch = 'Amd64, .. } =>
    {
      name = "glibc-bedrock-2.42-sysroot",
      build_deps = [],
      runtime_deps = [
        subsetOf glibc-bedrock-2-42 ["sysroot_lib", "sysroot_include"],
      ],
      cmd = "",
      outputs = {},
    } | BuildSpec,
  { arch = 'Arm64, .. } =>
    {
      name = "glibc-bedrock-2.42-sysroot",
      build_deps = [],
    } | BuildSpec,
} target
