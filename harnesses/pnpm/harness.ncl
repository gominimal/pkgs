let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pnpm",

  runtime_packages = ["node"],
  build_packages = ["pnpm", "base"],

  build_cmds_cmd = ["/bin/bash", "-c", m%"
    [ ! -d node_modules ] || ! pnpm install --verbose --frozen-lockfile --prefer-offline 2>/dev/null && echo '/bin/pnpm install'
    echo '/bin/pnpm build'
  "%],
}
