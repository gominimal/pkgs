# libsigsegv — GNU library for page-fault / stack-overflow handling in user
# mode. A Maude (rewriting engine) build prerequisite; see pkgmgr-rs#528.
let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.16" in
{
  name = "libsigsegv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libsigsegv-%{version}.tar.gz",
      sha256 = "f8b2fac06c091fc29d6474733d118dc163ed7cd6be4783240d31ad7af11efa30",
      extract = true,
      strip_prefix = "libsigsegv-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "libsigsegv",
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
            m%%"
              set -e
              gcc -x c - -o t -lsigsegv <<'EOF'
              #include <sigsegv.h>
              int main(void) { return libsigsegv_version > 0 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
