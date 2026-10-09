let { stack, .. } = import "minimal.ncl" in
# Shared by every Ruby stack (`ruby`, `rails`, and the `-3.x` series variants):
# what a Ruby project needs to `bundle install` and run, which extra packages
# its Gemfile.lock implies, and how a project's Ruby version is detected.
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
let parts = {
  # Always present: Ruby, a compiler for native extensions (most real
  # Gemfiles have one), and what gem extconf scripts quietly assume.
  # linux_headers: several gems include <linux/*.h>. which: charlock_holmes'
  # extconf shells out to it. tzdata: tzinfo reads the system zoneinfo.
  build_packages = [
    "gcc", "binutils", "make", "pkgconf", "linux_headers",
    "libyaml", "libffi", "openssl", "zlib", "readline", "gmp",
    "which", "file", "tzdata", "git",
  ],

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
    "pgvector" =
      any_gem ["neighbor", "pgvector"]
      @ [
        { file_regexes."db/schema.rb" = "enable_extension \"vector\"" },
        { file_regexes."db/structure.sql" = "(?i)CREATE EXTENSION (IF NOT EXISTS )?vector" },
      ],
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
    # Process runner for Procfile.dev (bin/dev prefers it over foreman;
    # some apps, e.g. Chatwoot's `make run`, call it directly).
    "overmind" = [{ file_regexes."Procfile.dev" = "*" }],
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
in

# A project asks for Ruby X.Y in any of these places. Each is one matcher entry.
let version_entries = fun series =>
  let s = std.string.replace "." "\\." series in
  [
    { file_regexes.".ruby-version" = "^(ruby-)?%{s}([.\\s]|$)" },
    { file_regexes.".tool-versions" = "(?m)^ruby\\s+%{s}([.\\s]|$)" },
    { file_regexes."Gemfile" = "(?m)^\\s*ruby\\s+[\"'](~>\\s*|>=\\s*)?%{s}([.\"']|$)" },
    { file_regexes."Gemfile.lock" = "(?m)^RUBY VERSION\\s*\\n\\s+ruby %{s}\\." },
  ]
in
let railties = "(?m)^    railties \\("
in
{
  # Builds one stack.
  #   ruby_package: which Ruby the session gets (`ruby`, `ruby-3.4`, ...).
  #   series:       null for the default stack, or "3.4" etc. to match only
  #                 projects that ask for that Ruby.
  #   rails:        true to match only Rails apps (railties in Gemfile.lock).
  mk = fun args =>
    let { name, ruby_package, series, rails, prio } = args in
    let detect =
      if series == null then
        if rails then
          [
            { file_regexes."Gemfile.lock" = railties },
            # Not locked yet (a fresh `rails new --skip-bundle`, a template).
            { file_regexes."Gemfile" = "(?m)^\\s*gem\\s+[\"']rails[\"']" },
          ]
        else [{ file_regexes."Gemfile" = "*" }]
      else
        let entries = version_entries series in
        if rails then
          # railties AND the version. One regex per file per entry, so when
          # the version lives in Gemfile.lock too, require both in one regex
          # (railties sits under GEM, before the RUBY VERSION section).
          std.array.map
            (fun e =>
              if std.record.has_field "Gemfile.lock" e.file_regexes then
                { file_regexes."Gemfile.lock" = "(?ms)^    railties \\(.*^RUBY VERSION\\s*\\n\\s+ruby %{std.string.replace "." "\\." series}\\." }
              else
                { file_regexes = e.file_regexes & { "Gemfile.lock" = railties } }
            )
            entries
        else
          std.array.map
            (fun e =>
              if std.record.has_field "Gemfile" e.file_regexes then e
              else { file_regexes = e.file_regexes & { "Gemfile" = "*" } }
            )
            entries
    in
    stack {
      name = args.name,
      build_packages = parts.build_packages,
      runtime_packages = [ruby_package],
      build_env_vars = parts.build_env_vars,
      build_cmd = "bundle install",
      matches_project_if_any =
        std.array.map
          (fun d => d & { runtime_package_if_any = parts.runtime_package_if_any })
          detect,
      matches_project_priority = prio,
    },
}
