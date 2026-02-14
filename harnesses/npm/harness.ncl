let { harness, .. } = import "minimal.ncl" in
harness {
  name = "npm",

  runtime_packages = ["node"],
  build_packages = ["base", "curl"],
  build_env_vars = {
    NPM_CONFIG_CACHE = "/state/npm-cache",
  },

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    [ -f package-lock.json ] && echo '/bin/npm ci' || echo '/bin/npm install'
    echo '/bin/npm run build --if-present'
  "%
  ],
}
