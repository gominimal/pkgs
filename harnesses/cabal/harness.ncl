let { harness, .. } = import "minimal.ncl" in
harness {
  name = "cabal",

  build_packages = ["ghc", "cabal", "base"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    echo '/bin/bash -c "set -ex; cabal build --enable-tests --enable-benchmarks 2>/dev/null || cabal build"'
    "%
  ],

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  matches_project_if_any = [
    {
      file_regexes."cabal.project" = "*",
    },
  ],
}
