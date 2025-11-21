let {profile, ..} = import "minimal.ncl" in

profile {
  name = "rust",
  packages = ["rust", "gcc", "binutils"],

  env_vars = {
    CC = "gcc",
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "gcc",
  },
}
