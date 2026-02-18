let { harness, .. } = import "minimal.ncl" in
harness {
  name = "bun",
  runtime_packages = ["bun"],
  build_packages = ["base", "curl"],
  build_cmds_cmd = [
    "/bin/bash", "-c",
    m%"
    echo '/bin/bun install'
    echo '/bin/bun run build'
    "%
  ],
}
