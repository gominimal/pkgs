let { stack, .. } = import "minimal.ncl" in
stack {
  name = "zig",
  build_packages = ["zig", "base", "glibc", "linux_headers"],
  build_cmd = "zig build -Doptimize=ReleaseSafe",

  matches_project_if_any = [
    {
      file_regexes = {
        "build.zig" = "*",
      },
    }
  ],
}
