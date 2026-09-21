# Imported from Wolfi `lsof` by `pkgmgr import wolfi` (autotools build).
# TODO: REVIEWER — verify deps/outputs/runtime_deps + the build.sh opts.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let groff = import "../groff/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "4.99.7" in
{
  name = "lsof",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    autoconf,
    groff,
    automake,
    libtool,
    m4,
    make,
    pkgconf,
    toolchain,
    glibc,
    {
      url = "https://github.com/lsof-org/lsof/archive/refs/tags/%{version}.tar.gz",
      sha256 = "bac1b0acbc50aede42fc97dffaa0b0475e97973e36a6351de5f349c6155afc68",
      extract = true,
      strip_prefix = "lsof-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "lsof-org", repo = "lsof" },
      license_spdx = "lsof",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Rewritten from the Wolfi-ported block, which had TWO assertions that
          # could not fail:
          #   * `ver="${{package.version}}"` was an unsubstituted Wolfi template.
          #     In bash it expands to empty, so `grep -F -- "$ver"` matched any
          #     output at all and the version check passed unconditionally.
          #   * the open-file check ran `grep -F "$tmpfile"` and then IGNORED its
          #     exit status, printed PASS, and ended with a cleanup command whose
          #     zero exit became the result (CodeRabbit, #721).
          # Both now fail loudly: `set -euo pipefail` plus `grep -q`.
          ["/bin/bash", "-c", "set -euo pipefail\n/bin/lsof -h 2>&1 | grep -qi usage"],
          ["/bin/bash", "-c", "set -euo pipefail\n/bin/lsof -v 2>&1 | grep -qF %{version}"],
          ["/bin/bash", "-c", "set -euo pipefail\ntmpfile=$(mktemp /tmp/lsof-test-XXXXXX)\ntrap 'kill $bg_pid 2>/dev/null || true; rm -f \"$tmpfile\"' EXIT\necho data > \"$tmpfile\"\nsh -c \"exec 3<\\\"$tmpfile\\\"; sleep 60\" &\nbg_pid=$!\nsleep 1\n/bin/lsof -p \"$bg_pid\" 2>&1 | grep -qF \"$tmpfile\""],
        ],
      } | Test,
  },
} | BuildSpec
