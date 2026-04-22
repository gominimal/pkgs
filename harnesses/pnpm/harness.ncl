let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pnpm",

  runtime_packages = ["node-lts"],
  build_packages = ["pnpm", "base"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    # Run pnpm install if no packages are installed (first start)
    [ -z "$(pnpm list 2>/dev/null)" ] && echo "/bin/pnpm install"
    echo '/bin/pnpm build'
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "pnpm-lock.yaml" = "*",
        "pnpm-workspace.yaml" = "*",
      },
    }
  ],
  matches_project_priority = 10, # Higher than npm
}
