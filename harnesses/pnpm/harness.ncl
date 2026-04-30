let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pnpm",

  runtime_packages = ["node-lts"],
  build_packages = ["pnpm", "base"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    [ -f pnpm-lock.yaml ] && echo '/bin/pnpm install --frozen-lockfile' || echo '/bin/pnpm install'
    echo '/bin/pnpm build'
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "pnpm-lock.yaml" = "*",
      },
    }
  ],
  matches_project_priority = 10, # Higher than npm
}
