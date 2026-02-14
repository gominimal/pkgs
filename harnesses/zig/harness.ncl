let { harness, .. } = import "minimal.ncl" in
harness {
  name = "zig",
  build_packages = ["zig", "base", "glibc", "linux_headers"],
  build_env_vars = {
    ZIG_LOCAL_CACHE_DIR = "/state/zig-cache",
    ZIG_GLOBAL_CACHE_DIR = "/state/zig-global-cache",
  },
  build_cmd = "zig build -Doptimize=ReleaseSafe",
}
