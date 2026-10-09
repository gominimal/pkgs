let common = import "../ruby/common.ncl" in
# A Rails app that asks for Ruby 3.3.
common.mk {
  name = "rails-3.3",
  ruby_package = "ruby-3.3",
  series = "3.3",
  rails = true,
  prio = 25,
}
