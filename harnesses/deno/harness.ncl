let { harness, .. } = import "minimal.ncl" in
harness {
  name = "deno",
  runtime_packages = ["deno"],
  build_packages = ["base", "curl"],
  build_cmd = "deno compile --allow-net --allow-read --output ./build/app main.ts",

  # Predicates for when this harness is usable in a source tree - powers `minimal init`
  project_matchers = [
    {
      file_regexes."deno.json" = "*",
    },
    {
      file_regexes."deno.jsonc" = "*",
    },
  ],
}
