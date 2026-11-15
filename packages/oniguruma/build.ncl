let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.9.10" in
{
  name = "oniguruma",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/kkos/oniguruma/releases/download/v%{version}/onig-%{version}.tar.gz",
      sha256 = "2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05",
      extract = true,
      strip_prefix = "onig-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libonig.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libonig.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "kkos",
        repo = "oniguruma",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              cd /tmp
              gcc -x c - -o t -x none -lonig <<'EOF'
              #include <stdio.h>
              #include <string.h>
              #include <oniguruma.h>
              int main(void) {
                OnigEncoding enc = ONIG_ENCODING_UTF8;
                onig_initialize(&enc, 1);
                regex_t *re; OnigErrorInfo ei;
                const UChar *pat = (const UChar *)"a(b+)c", *s = (const UChar *)"xxabbbc";
                if (onig_new(&re, pat, pat + strlen((char *)pat), ONIG_OPTION_NONE, enc, ONIG_SYNTAX_DEFAULT, &ei) != ONIG_NORMAL) return 1;
                OnigRegion *rg = onig_region_new();
                int r = onig_search(re, s, s + 7, s, s + 7, rg, ONIG_OPTION_NONE);
                printf("onig %s match at %d\n", onig_version(), r);
                onig_region_free(rg, 1); onig_free(re); onig_end();
                return r != 2;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
