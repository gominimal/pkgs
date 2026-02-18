let { harness, .. } = import "minimal.ncl" in
harness {
  name = "zig",
  build_packages = ["zig", "base", "glibc", "linux_headers"],
  build_cmd = "zig build -Doptimize=ReleaseSafe",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes = {
        "build.zig" = "*",
      },
    }
  ],
}
