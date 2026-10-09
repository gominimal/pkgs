# Shared by the `ruby` and `rails` stacks: what a Ruby project needs to
# `bundle install` and run, and which extra packages its Gemfile.lock implies.
#
# Gems are matched in Gemfile.lock, where each resolved gem sits on its own
# line indented four spaces under `specs:` (`    pg (1.5.9)`, or with a
# platform suffix `    nokogiri (1.18.8-aarch64-linux-gnu)`), so a gem is
# present iff `(?m)^    <name> \(` matches. Gemfile is the fallback for a
# project that has not locked yet.
let gem = fun name =>
  [
    { file_regexes."Gemfile.lock" = "(?m)^    %{name} \\(" },
    { file_regexes."Gemfile" = "(?m)^\\s*gem\\s+[\"']%{name}[\"']" },
  ]
in
let any_gem = fun names => std.array.flat_map gem names in
{
  # Always present: Ruby, a compiler for native extensions (most real
  # Gemfiles have one), and what gem extconf scripts quietly assume.
  # linux_headers: several gems include <linux/*.h>. which: charlock_holmes'
  # extconf shells out to it. tzdata: tzinfo reads the system zoneinfo.
  build_packages = [
    "gcc", "binutils", "make", "pkgconf", "linux_headers",
    "libyaml", "libffi", "openssl", "zlib", "readline", "gmp",
    "which", "file", "tzdata", "git",
  ],
  runtime_packages = ["ruby"],

  build_env_vars = {
    # gcc ships no `cc`, and many native gem builds call `cc` unless CC says
    # otherwise (hiredis-client, ...). Same as the rust stack.
    CC = "gcc",
    CXX = "g++",
    # Selenium (Rails system tests, Capybara): use the packaged headless
    # shell + pinned chromedriver (added below when selenium-webdriver is
    # locked); Selenium Manager never downloads a browser or driver.
    SE_OFFLINE = "true",
    SE_BROWSER_PATH = "/usr/bin/chromium-headless-shell",
  },

  runtime_package_if_any = {
    # Databases and services.
    "postgres" = any_gem ["pg"],
    "glibc-locale-c-utf8" = any_gem ["pg"],
    "mariadb" = any_gem ["mysql2", "trilogy"],
    "sqlite" = any_gem ["sqlite3"],
    "redis" = any_gem ["redis", "redis-client", "sidekiq", "resque", "kredis", "hiredis-client"],
    # Native libraries behind common gems.
    "libvips" = any_gem ["ruby-vips"],
    "icu" = any_gem ["charlock_holmes"],
    "libidn" = any_gem ["idn-ruby"],
    # Gems that shell out to ffmpeg. Not Active Storage itself: every Rails
    # app has it, and video previews alone don't justify ffmpeg's closure.
    "ffmpeg" = any_gem ["streamio-ffmpeg", "paperclip", "kt-paperclip"],
    # Browser tests.
    "chromium-headless-shell-bin" = any_gem ["selenium-webdriver", "cuprite", "ferrum"],
    "chromedriver-bin" = any_gem ["selenium-webdriver"],
    # JavaScript side: jsbundling/cssbundling, Vite, or a frontend in the repo.
    "node-lts" = [
      { file_regexes."package.json" = "*" },
    ],
    # Yarn 1 lockfiles say so on their first lines; Yarn 2+ ("berry") ones
    # carry `__metadata:` and get the Corepack-backed yarn, which runs the
    # release pinned in package.json's packageManager.
    "yarn" = [{ file_regexes."yarn.lock" = "# yarn lockfile v1" }],
    "yarn-corepack" = [
      { file_regexes."yarn.lock" = "(?m)^__metadata:" },
      { file_regexes."package.json" = "\"packageManager\"\\s*:\\s*\"yarn@[2-9]" },
    ],
    "pnpm" = [{ file_regexes."pnpm-lock.yaml" = "*" }],
    "bun" = [{ file_regexes."bun.lockb" = "*" }, { file_regexes."bun.lock" = "*" }],
  },
}
