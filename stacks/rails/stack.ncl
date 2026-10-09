let { stack, .. } = import "minimal.ncl" in
let common = import "../ruby/common.ncl" in
# A Rails app: the `ruby` stack's packages and gem-driven extras, at a
# priority above the JavaScript stacks, because jsbundling/cssbundling/Vite
# apps carry a package.json (and lockfile) at the root too.
stack {
  name = "rails",

  build_packages = common.build_packages,
  runtime_packages = common.runtime_packages,
  build_env_vars = common.build_env_vars,

  build_cmd = "bundle install",

  matches_project_if_any = [
    {
      file_regexes."Gemfile.lock" = "(?m)^    railties \\(",
      runtime_package_if_any = common.runtime_package_if_any,
    },
  ],
  matches_project_priority = 20, # Higher than pnpm / pulumi-nodejs
}
