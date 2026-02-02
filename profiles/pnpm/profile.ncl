let { profile, .. } = import "minimal.ncl" in

profile {
  name = "pnpm",
  packages = ["pnpm"],
}
