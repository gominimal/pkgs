let { harness, .. } = import "minimal.ncl" in
harness {
  name = "uv",

  build_packages = ["uv", "base", "toolchain"],
  runtime_packages = ["python"],
  build_env_vars = {
    UV_CACHE_DIR = "/state/uv-cache",
  },

  build_cmds_cmd = [
    "/bin/bash", "-c",
    m%"
    echo '/bin/uv sync'
    echo '/bin/uv build'
    "%
  ],
}
