let { profile, .. } = import "minimal.ncl" in

profile {
  name = "rust",
  packages = ["rust", "gcc", "binutils"],

  env_vars = {
    # An attribute on the 'rust' package already wires a state
    # directory `.cargo`, set to `$CARGO_HOME`. We set the location
    # for storing built packages to `$CARGO_HOME/build`, so incremental
    # artifacts are stored in the state dir also.
    CARGO_BUILD_BUILD_DIR = "{cargo-cache-home}/build",

    # Environment variables that configure the compiler/linker
    CC = "gcc",
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "gcc",
  },
}
