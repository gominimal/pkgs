let { harness, .. } = import "minimal.ncl" in
harness {
  name = "bun",
  runtime_packages = ["bun"],
  build_packages = ["base", "curl"],
  build_env_vars = {
    BUN_INSTALL_CACHE_DIR = "/state/bun-cache",
  },
  build_cmds_cmd = [
    "/bin/bash", "-c",
    m%"
    echo '/bin/bun install'
    echo '/bin/bun run build'
    "%
  ],
}
