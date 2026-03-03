let { harness, .. } = import "minimal.ncl" in
harness {
  name = "shell",
  build_packages = ["base", "curl"],
  build_cmd = ["bash", "-c", "echo \"Error: minimal is configured with the fallback shell harness which cannot build\" >&2 && exit 1"],
}
