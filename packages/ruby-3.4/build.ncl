let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let patch = import "../patch/build.ncl" in
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

# Ruby 3.4.x, for apps that pin an older Ruby (.ruby-version / .tool-versions).
# A drop-in alternative to `ruby` at the same paths (like node-lts vs node):
# put exactly one Ruby package in a loadout. Stays on the 3.4 series; bump only
# within it.
let version = "3.4.11" in
let abi = std.string.join "." (std.array.slice 0 2 (std.string.split "." version)) in
{
  name = "ruby-3.4",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "rubygems-bindir-mkdir-p.patch" } | Local,
    {
      url = "https://cache.ruby-lang.org/pub/ruby/3.4/ruby-%{version}.tar.gz",
      sha256 = "5c22be44524312b3d433d68739bcc530633b1da5ef8ba0afa0a37680da17d3de",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    patch,
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
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/ruby --version | grep -q '^ruby 3\\.4\\.11'"],
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
