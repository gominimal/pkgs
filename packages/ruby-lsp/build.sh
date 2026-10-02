#!/bin/bash
set -euo pipefail

# Vendor the gem and its pinned dependency closure (the .gem Sources
# fetched into the cwd) into a dedicated GEM_HOME under the package's
# own prefix. --local resolves dependencies from the .gem files in the
# working directory only — no rubygems.org access at build time.
GEMS="$OUTPUT_DIR/usr/lib/ruby-lsp/gems"
mkdir -p "$GEMS"
export GEM_HOME="$GEMS"
export GEM_PATH="$GEMS"
# --bindir is explicit because the ruby package ships a system gemrc
# defaulting binstubs to ~/.local/bin (gominimal/inbox#584); CLI flags
# beat gemrc, keeping this vendored install self-contained.
gem install --local --no-document --bindir "$GEMS/bin" "ruby-lsp-$MINIMAL_ARG_VERSION.gem"

# Drop install residue that is either non-reproducible (gem_make.out and
# mkmf.log record a per-run temp dir name like .gem.20260823-3-k0190w)
# or dead weight at runtime (the downloaded .gem archives and the native
# extensions' intermediate objects). The built .so files live in both
# extensions/ and the gem's lib/ dir, so nothing needed survives only
# under ext/.
rm -rf "$GEMS/cache"
find "$GEMS" \( -name gem_make.out -o -name mkmf.log \) -delete
find "$GEMS/gems" -path '*/ext/*' -name '*.o' -delete

# Wrapper: keep the vendored gems on GEM_PATH so the launcher bootstraps
# without a network, but point GEM_HOME at a writable per-user dir.
# ruby-lsp always starts through a per-project "composed bundle"
# (ruby-lsp-launcher writes a private Gemfile and runs `bundle install`,
# pulling the project's gems plus the newest ruby-lsp), and bundler's
# default install target is GEM_HOME — with the read-only vendored store
# there it dies at startup with Bundler::ReadOnlyFileSystemError, which
# eglot reports as "server died". Composed installs land in the cache
# instead and are reused across projects.
mkdir -p "$OUTPUT_DIR/usr/bin"
cat > "$OUTPUT_DIR/usr/bin/ruby-lsp" << 'EOF'
#!/bin/sh
GEM_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ruby-lsp/gems"
mkdir -p "$GEM_CACHE"
export GEM_HOME="$GEM_CACHE"
export GEM_PATH="$GEM_CACHE:/usr/lib/ruby-lsp/gems"
exec /usr/lib/ruby-lsp/gems/bin/ruby-lsp "$@"
EOF
chmod +x "$OUTPUT_DIR/usr/bin/ruby-lsp"
