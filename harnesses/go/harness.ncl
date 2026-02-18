let { harness, .. } = import "minimal.ncl" in
harness {
  name = "go",
  build_packages = ["go", "binutils", "linux_headers"],
  build_cmd = "go build",
}
