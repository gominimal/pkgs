let { harness, .. } = import "minimal.ncl" in
harness {
  name = "deno",
  runtime_packages = ["deno"],
  build_packages = ["base", "curl"],
  build_cmd = "deno compile --allow-net --allow-read --output ./build/app main.ts",
}
