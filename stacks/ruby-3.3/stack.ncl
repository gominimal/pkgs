let common = import "../ruby/common.ncl" in
# A Ruby project that asks for Ruby 3.3 (.ruby-version, .tool-versions,
# the Gemfile's `ruby` line, or Gemfile.lock's RUBY VERSION).
common.mk {
  name = "ruby-3.3",
  ruby_package = "ruby-3.3",
  series = "3.3",
  rails = false,
  prio = -5,
}
