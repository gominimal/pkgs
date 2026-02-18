let { harness, .. } = import "minimal.ncl" in
harness {
  name = "go",
  build_packages = ["go", "binutils", "linux_headers"],
  build_cmd = "go build",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes = {
        "go.mod" = "*",
        "go.sum" = "*",
      },
    }
  ],
}
