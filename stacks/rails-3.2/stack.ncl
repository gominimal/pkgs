let common = import "../ruby/common.ncl" in
# A Rails app that asks for Ruby 3.2.
common.mk {
  name = "rails-3.2",
  ruby_package = "ruby-3.2",
  series = "3.2",
  rails = true,
  prio = 25,
}
