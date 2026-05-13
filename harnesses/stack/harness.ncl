let { harness, .. } = import "minimal.ncl" in
harness {
  name = "stack",

  build_packages = ["stack", "ghc", "base"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"\
    echo '/bin/bash -c "set -ex; stack build"'\
    "%,
  ],

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  matches_project_if_any = [
    {
      file_regexes."stack.yaml" = "*",
    },
  ],
}
