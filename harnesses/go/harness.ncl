let { harness, .. } = import "minimal.ncl" in
harness {
  name = "go-harness",
  build_packages = ["go", "binutils", "linux_headers"],
  build_env_vars = {},
  build_cmd = "go build",
}
