let { Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.0" in
{
  name = "tree-sitter-lua",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-lua/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cf01b93f4b61b96a6d27942cf28eeda4cbce7d503c3bef773a8930b3d778a2d9",
      extract = true,
      strip_prefix = "tree-sitter-lua-%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    parser = { glob = "usr/lib/nvim/parser/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tree-sitter-grammars",
        repo = "tree-sitter-lua",
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
                if (check("/usr/lib/nvim/parser/lua.so", "tree_sitter_lua", "local x = 1")) return 1;
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
