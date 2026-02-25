let { harness, .. } = import "minimal.ncl" in
harness {
  name = "shell",
  build_packages = ["base"],
  build_cmd = "true",
}
