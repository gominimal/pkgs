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
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "fail() { echo \"FAIL:\" \"$@\"; exit 1; }\n\n# both -h and -v output to stderr\nlsof -h 2>&1 || fail \"'lsof -h' exited $?\"\necho \"PASS: 'lsof -h' exited 0\"\n\nver=\"${{package.version}}\"\nout=$(lsof -v 2>&1) || fail \"'lsof -v' exited $?\"\necho \"$out\" | grep -F -- \"$ver\" ||\n  fail \"'lsof -v' output did not include '$ver': $out\"\necho \"PASS: 'lsof -v' contained version '$ver' in output\""],
          ["/bin/bash", "-c", "# Create a test file and hold it open with a background process\ntmpfile=$(mktemp /tmp/lsof-test-XXXXXX)\necho \"lsof test data\" > \"$tmpfile\"\n\n# Hold the file open by reading from it in a background sleep via shell redirection\nsh -c \"exec 3<\\\"$tmpfile\\\"; sleep 60\" &\nbg_pid=$!\n\n# Give the background process a moment to start\nsleep 1\n\n# Verify lsof can list open files for the current shell process\noutput=$(lsof -p $$ 2>&1)\necho \"$output\" | grep -F . || { echo \"FAIL: lsof -p $$ produced no output\"; exit 1; }\necho \"PASS: lsof -p $$ listed open files for current process\"\n\n# Verify lsof can find the specific open file held by the background process\nlsof_output=$(lsof -p \"$bg_pid\" 2>&1)\necho \"$lsof_output\" | grep -F \"$tmpfile\"\necho \"PASS: lsof found the open test file for background process $bg_pid\"\n\n# Clean up\nkill \"$bg_pid\"\nrm -f \"$tmpfile\""],
        ],
      } | Test,
  },
} | BuildSpec
