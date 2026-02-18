let { harness, .. } = import "minimal.ncl" in
harness {
  name = "pip",

  runtime_packages = ["python", "pip"],
  build_packages = ["setuptools", "go"], # TODO: 'go' isnt needed, just used to set side-effect of inter

  build_cmd = "pip3 install --target ./build .",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes."requirements.txt" = "*",
    },
    {
      file_regexes."setup.py" = "*",
    },
  ],
}
