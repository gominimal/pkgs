let { stack, .. } = import "minimal.ncl" in
let common = import "common.ncl" in
# Any Ruby project with a Gemfile. Default priority, so a JavaScript repo
# that only carries a Gemfile for tooling (fastlane, danger) stays with its
# JS stack; Rails apps are picked up by the higher-priority `rails` stack.
stack {
  name = "ruby",

  build_packages = common.build_packages,
  runtime_packages = common.runtime_packages,
  build_env_vars = common.build_env_vars,

  build_cmd = "bundle install",

  matches_project_if_any = [
    {
      file_regexes."Gemfile" = "*",
      runtime_package_if_any = common.runtime_package_if_any,
    },
  ],
}
