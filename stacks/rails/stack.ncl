let common = import "../ruby/common.ncl" in
# A Rails app (railties in Gemfile.lock), on the default Ruby. Above the JS
# stacks: jsbundling/cssbundling/Vite apps carry a package.json at the root.
common.mk {
  name = "rails",
  ruby_package = "ruby",
  series = null,
  rails = true,
  prio = 20,
}
