let { Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Ships two grammars from one repo: block-level (markdown.so) and
# inline-level (markdown_inline.so). Neovim needs both.
let version = "0.5.4" in
{
  name = "tree-sitter-markdown",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "481ce2c1cce7b1130bc8455c186052bd0fa461f1ff488666994c6a3da7fca2ac",
      extract = true,
      strip_prefix = "tree-sitter-markdown-%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    parsers = { glob = "usr/lib/nvim/parser/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tree-sitter-grammars",
        repo = "tree-sitter-markdown",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, tree-sitter],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              cd /tmp
              gcc -x c - -o t -x none -ltree-sitter -ldl <<'EOF'
              #include <dlfcn.h>
              #include <stdio.h>
              #include <string.h>
              #include <tree_sitter/api.h>
              static int check(const char *so, const char *sym, const char *code) {
                void *h = dlopen(so, RTLD_NOW);
                if (!h) { fprintf(stderr, "%s\n", dlerror()); return 1; }
                const TSLanguage *(*fn)(void) = (const TSLanguage *(*)(void))dlsym(h, sym);
                if (!fn) { fprintf(stderr, "no %s\n", sym); return 1; }
                TSParser *p = ts_parser_new();
                if (!ts_parser_set_language(p, fn())) { fprintf(stderr, "abi mismatch %s\n", so); return 1; }
                TSTree *t = ts_parser_parse_string(p, NULL, code, strlen(code));
                TSNode r = ts_tree_root_node(t);
                int bad = ts_node_has_error(r) || ts_node_child_count(r) == 0;
                ts_tree_delete(t);
                ts_parser_delete(p);
                return bad;
              }
              int main(void) {
                if (check("/usr/lib/nvim/parser/markdown.so", "tree_sitter_markdown", "# title\n\ntext\n")) return 1;
                if (check("/usr/lib/nvim/parser/markdown_inline.so", "tree_sitter_markdown_inline", "some *emphasis*")) return 1;
                return 0;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
