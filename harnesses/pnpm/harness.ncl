let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pnpm",

  runtime_packages = ["node"],
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

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes = {
        "pnpm-lock.yaml" = "*",
        "pnpm-workspace.yaml" = "*",
      },
    }
  ],
}
