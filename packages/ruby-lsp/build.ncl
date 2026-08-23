let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let ruby = import "../ruby/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.26.10" in
{
  name = "ruby-lsp",
  # Shopify's Ruby language server, vendored into its own GEM_HOME at
  # build time (same needs-internet pattern as mermaid-cli's npm
  # install; the version is pinned here and passed to `gem install`).
  # `make` is needed because the prism and rbs dependencies compile
  # native extensions via mkmf, and neither base nor toolchain carries
  # make as a runtime dep.
  build_deps = [
    { file = "build.sh" } | Local,
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

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

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
