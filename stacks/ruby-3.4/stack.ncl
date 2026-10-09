let common = import "../ruby/common.ncl" in
# A Ruby project that asks for Ruby 3.4 (.ruby-version, .tool-versions,
# the Gemfile's `ruby` line, or Gemfile.lock's RUBY VERSION).
common.mk {
  name = "ruby-3.4",
  ruby_package = "ruby-3.4",
  series = "3.4",
  rails = false,
  prio = -5,
}
