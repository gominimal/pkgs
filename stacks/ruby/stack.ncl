let common = import "../ruby/common.ncl" in
# Any Ruby project with a Gemfile, on the default Ruby. Below the JS stacks
# (npm is 0), so a JavaScript repo that only carries a Gemfile for tooling
# (fastlane, danger) stays with its JS stack.
common.mk {
  name = "ruby",
  ruby_package = "ruby",
  series = null,
  rails = false,
  prio = -10,
}
