let { stack, .. } = import "minimal.ncl" in
stack {
  name = "cabal",

  build_packages = ["ghc", "cabal", "base"],

  build_cmd = "cabal build",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  matches_project_if_any = [
    {
      file_regexes."cabal.project" = "*",
    },
    {
      file_regexes."*.cabal" = "*",
    },
  ],
}
