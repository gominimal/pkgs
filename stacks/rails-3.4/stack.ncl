let common = import "../ruby/common.ncl" in
# A Rails app that asks for Ruby 3.4.
common.mk {
  name = "rails-3.4",
  ruby_package = "ruby-3.4",
  series = "3.4",
  rails = true,
  prio = 25,
}
