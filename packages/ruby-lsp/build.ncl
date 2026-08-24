let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let ruby = import "../ruby/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.26.10" in
{
  name = "ruby-lsp",
  # Shopify's Ruby language server, vendored into its own gem dir at
  # build time. The complete RubyGems closure is pinned below as .gem
  # Sources and installed offline with `gem install --local`: a bare
  # `gem install ruby-lsp` would resolve its floating version ranges
  # (language_server-protocol ~> 3.17.0, rbs >= 3 < 5, ...) against
  # rubygems.org at build time, so two builds of the same spec could
  # pick different inputs. rbs's prism/tsort deps are satisfied by Ruby
  # 4.0's default gems and its jar-dependencies dep is JRuby-only, so
  # none of those need vendoring. `make` is needed because the rbs
  # dependency compiles a native extension via mkmf, and neither base
  # nor toolchain carries make.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://rubygems.org/downloads/ruby-lsp-%{version}.gem",
      sha256 = "e67284af94423531f6b9a583350596421b5a6a4dd93083f1c2ba03da7c23bbed",
    } | Source,
    {
      url = "https://rubygems.org/downloads/language_server-protocol-3.17.0.6.gem",
      sha256 = "5ef2c0c138f8267e1bc631d3328347d354f96724b0af22f2c79516120443b7f0",
    } | Source,
    {
      url = "https://rubygems.org/downloads/logger-1.7.0.gem",
      sha256 = "196edec7cc44b66cfb40f9755ce11b392f21f7967696af15d274dde7edff0203",
    } | Source,
    {
      url = "https://rubygems.org/downloads/rbs-4.1.3.gem",
      sha256 = "0c4474a9751cdc14364bfad0b3e53678323bbdc2c31683b0445932867dbab8c4",
    } | Source,
    base,
    make,
    ruby,
    toolchain,
  ],

  # make + toolchain at *runtime* as well: ruby-lsp always starts through a
  # per-project composed bundle (`bundle install` at launch, see build.sh),
  # and that bundle contains native-extension gems (prism, rbs, debug,
  # io-console, ...) that mkmf must be able to compile in the session.
  # Without a compiler the install fails and eglot reports "server died".
  runtime_deps = [
    base,
    make,
    ruby,
    toolchain,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    ruby-lsp = { glob = "usr/bin/ruby-lsp" } | OutputBin,
    gems = { glob = "usr/lib/ruby-lsp/**", allow_executable = true } | OutputData,
  },

  tests = {
    version = standaloneTest "ruby-lsp --version",

    # Guards the two regressions behind eglot's "server died": ruby-lsp
    # composes a per-project bundle at launch and runs `bundle install`,
    # which requires (1) the wrapper to select a writable GEM_HOME under
    # XDG_CACHE_HOME rather than the read-only vendored store, and (2) a
    # runtime env that can compile native-extension gems (prism, debug,
    # io-console, ...). The full composed startup needs rubygems.org and
    # floats to the newest release, so it is deliberately not tested here;
    # these two offline checks cover the failure modes we actually hit.
    composed_bundle_prereqs =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [
          ["/bin/bash", "-c", "export XDG_CACHE_HOME=/tmp/xdg; ruby-lsp --version && test -d /tmp/xdg/ruby-lsp/gems"],
          ["/bin/bash", "-c", "cd $(mktemp -d) && printf 'void Init_t(void) {}\\n' > t.c && printf 'require \"mkmf\"\\ncreate_makefile(\"t\")\\n' > extconf.rb && ruby extconf.rb && make && test -f t.so"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Shopify",
        repo = "ruby-lsp",
      },
    } | Attrs,
} | BuildSpec
