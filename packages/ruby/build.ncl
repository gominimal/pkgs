let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libyaml = import "../libyaml/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "4.0.6" in
let abi = std.string.join "." (std.array.slice 0 2 (std.string.split "." version)) in
{
  name = "ruby",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://cache.ruby-lang.org/pub/ruby/4.0/ruby-%{version}.tar.gz",
      sha256 = "837d299e8f7ddf2be31a229a7a7e019d354979825117989acb3b32b1a9be262a",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    rust,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    gdbm,
    gmp,
    libffi,
    libyaml,
    ncurses,
    openssl,
    readline,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libruby*.so*" } | OutputLib,
    ruby_data = { glob = "usr/lib/ruby/**", allow_executable = true } | OutputData,
    includes = { glob = "usr/include/ruby*/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    gemrc = { glob = "usr/etc/gemrc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Ruby",
      # Ruby's own gem dir is read-only, so plain `bundle install` failed
      # ("File system is read-only"). Point GEM_HOME at persistent state:
      # writable, and gems survive across sessions. One dir per Ruby ABI
      # (major.minor) so compiled extensions never mix between versions.
      env_state_wiring = {
        env_var = "GEM_HOME",
        prefix = "ruby-gems-%{abi}",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "ruby",
        repo = "ruby",
      },
    } | Attrs,

  tests = {
    # A gem extension carrying GCC 14's new errors (here: a method function
    # of the wrong pointer type, as in scout_apm 5.x) still builds and loads.
    legacy_c_extension_builds =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, make],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              d=$(mktemp -d) && cd "$d"
              printf '%s\n' '#include <ruby.h>' 'static VALUE legacy(void) { return INT2FIX(42); }' \
                'void Init_legacy(void) { rb_define_singleton_method(rb_cObject, "legacy", legacy, 0); }' > legacy.c
              printf '%s\n' 'require "mkmf"' 'create_makefile("legacy")' > extconf.rb
              ruby extconf.rb >/dev/null
              make CC=gcc >build.log 2>&1 || { cat build.log >&2; exit 1; }
              test "$(ruby -I. -rlegacy -e 'print Object.legacy')" = 42
            "%
          ],
        ],
      } | Test,
    smoketest =
      {
        class = 'Standalone,
        cmds = [
          ["/usr/bin/ruby", "--version"],
        ],
      } | Test,

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "ruby -e 'puts 1+1' | grep -q '^2$'"],
        ],
      } | Test,

    # `gem install` puts a gem's executable in ~/.local/bin, where the session
    # PATH resolves it, even when the user's own gemrc sets `gem:` flags; and
    # `gem uninstall` removes it again (gominimal/inbox#584).
    gem_global_install =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              # Standalone tests run with the build-sandbox env (HOME=/state/home,
              # no ~/.local/bin on PATH), so each lookup below spells out a
              # session-like PATH that carries ~/.local/bin.
              printf 'gem: --no-document\n' > "$HOME/.gemrc"
              mkdir -p /tmp/g/bin && cd /tmp/g
              printf '#!/usr/bin/env ruby\nputs "ok"\n' > bin/gbin && chmod +x bin/gbin
              printf '%s\n' 'Gem::Specification.new do |s|' \
                '  s.name = "gbin"; s.version = "0.0.1"; s.summary = "t"; s.authors = ["t"]' \
                '  s.files = ["bin/gbin"]; s.executables = ["gbin"]' \
                'end' > gbin.gemspec
              gem build gbin.gemspec
              gem install --local ./gbin-0.0.1.gem
              test "$(PATH=/usr/bin:/bin:$HOME/.local/bin command -v gbin)" = "$HOME/.local/bin/gbin"
              test "$(PATH=/usr/bin:/bin:$HOME/.local/bin gbin)" = ok
              gem uninstall -x gbin
              test ! -e "$HOME/.local/bin/gbin"
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
