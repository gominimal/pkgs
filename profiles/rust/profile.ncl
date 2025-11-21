let {profile, ..} = import "minimal.ncl" in

profile {
  name = "rust",
  packages = ["rust", "gcc", "binutils"],

  env_vars = {
    CC = "gcc",
  },
}
