let { harness, .. } = import "minimal.ncl" in
harness {
  name = "deno",
  runtime_packages = ["deno"],
  build_packages = ["base", "curl"],
  build_env_vars = {
    DENO_DIR = "/state/deno-cache",
  },
  build_cmd = "deno compile --allow-net --allow-read --output ./build/app main.ts",
}
