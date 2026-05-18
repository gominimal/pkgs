let { harness, .. } = import "minimal.ncl" in
harness {
  name = "stack",

  build_packages = ["stack", "ghc", "base"],

  build_cmd = "stack build",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  matches_project_if_any = [
    {
      file_regexes."stack.yaml" = "*",
    },
  ],
}
