let { harness, .. } = import "minimal.ncl" in
harness {
  name = "uv",

  build_packages = ["uv", "base", "toolchain"],
  runtime_packages = ["python"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/uv sync'
    echo '/bin/uv build'
    "%
  ],

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes."uv.lock" = "*",
    },
    {
      file_regexes."pyproject.toml" = "*",
    },
  ],
}
