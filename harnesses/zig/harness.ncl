let { harness, .. } = import "minimal.ncl" in
harness {
  name = "zig",
  build_packages = ["zig", "base", "glibc", "linux_headers"],
  build_cmd = "zig build -Doptimize=ReleaseSafe",
}
