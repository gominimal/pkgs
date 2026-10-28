let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
# Sessions set LANG=C.UTF-8, which the glibc locale-archive lacks. Without it
# setlocale fails and Encoding.default_external falls back to US-ASCII, so a
# Rails app's string handling would depend on whether postgres (the only
# other carrier) is in the loadout. Until the glibc fold-in lands.
let glibc-locale-c-utf8 = import "../glibc-locale-c-utf8/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libyaml = import "../libyaml/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let zlib = import "../zlib/build.ncl" in

# Ruby 3.3.x, for apps that pin an older Ruby (.ruby-version / .tool-versions).
# A drop-in alternative to `ruby` at the same paths (like node-lts vs node):
# put exactly one Ruby package in a loadout. Stays on the 3.3 series; bump only
# within it.
let version = "3.3.13" in
{
  name = "ruby-3.3",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "rubygems-bindir-mkdir-p.patch" } | Local,
    {
      url = "https://cache.ruby-lang.org/pub/ruby/3.3/ruby-%{version}.tar.gz",
      sha256 = "4cae72e971bd1cdb20ca87d299111182417c5276c162de8ead0ab0531426cd61",
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
    # Verifies TLS against /etc/ssl/certs at runtime; see AGENTS.md "Trust store".
    ca-certificates,
    glibc-locale-c-utf8,
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
          ["/bin/bash", "-c", "/usr/bin/ruby --version | grep -qF 'ruby %{version} '"],
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

    # Under the session locale Ruby must read and write UTF-8, not US-ASCII.
    utf8_default_external =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "LANG=C.UTF-8 LC_ALL=C.UTF-8 ruby -e 'exit(Encoding.default_external == Encoding::UTF_8 ? 0 : 1)'"],
        ],
      } | Test,

    # OpenSSL's default paths (OPENSSLDIR=/etc/ssl) reach the store that the
    # ca-certificates runtime dep installs: every live per-root file under
    # /etc/ssl/certs must verify through `set_default_paths` alone. Offline;
    # without the runtime dep the directory is empty and the test fails. The
    # empty-store check is the control: no root verifies against no paths.
    # The 100-root floor counts LIVE roots, so a wrong sandbox clock that
    # filters every root out fails the test instead of verifying nothing.
    trust_store =
      {
        class = 'Standalone,
        cmds = [
          [
            "/usr/bin/ruby",
            "-ropenssl",
            "-e",
            m%"
              dir = "/etc/ssl/certs"
              now = Time.now
              files = Dir.glob("#{dir}/*.crt") - ["#{dir}/ca-certificates.crt"]
              roots = files.map { |f| OpenSSL::X509::Certificate.new(File.read(f)) }
              abort "control: an empty store verified a root" if roots.any? { |c| OpenSSL::X509::Store.new.verify(c) }
              live = roots.select { |c| c.not_before <= now && now < c.not_after }
              abort "only #{live.size} live roots (of #{roots.size}) under #{dir} at #{now}" if live.size < 100
              store = OpenSSL::X509::Store.new
              store.set_default_paths
              bad = live.reject { |c| store.verify(c) }
              abort "default paths reject #{bad.size} of #{live.size} live roots, e.g. #{bad.first.subject}" unless bad.empty?
            "%
          ],
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
