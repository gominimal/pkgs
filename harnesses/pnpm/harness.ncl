let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pnpm",

  runtime_packages = ["node"],
  build_packages = ["pnpm"],

  build_cmd = "pnpm build",
}
