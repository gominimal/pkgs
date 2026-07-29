let { stack, .. } = import "minimal.ncl" in
stack {
  name = "odin",
  build_packages = ["odin", "base", "glibc", "linux_headers"],

  # `odin build <dir>` treats the directory as a package and compiles every
  # .odin file in it. Odin's default is -o:minimal; -o:speed is the closer
  # analogue of what the other compiled-language stacks build by default.
  build_cmd = "odin build . -o:speed",

  # Odin has no manifest file -- no go.mod, no Cargo.toml, no build.zig -- so a
  # source tree is identified by the presence of .odin files themselves. ols.json
  # (Odin Language Server config) is a common but not universal companion.
  matches_project_if_any = [
    {
      file_regexes = {
        ".*\\.odin" = "*",
      },
    },
    {
      file_regexes = {
        "ols.json" = "*",
      },
    },
  ],
}
