# Imported from Wolfi `iputils` by `pkgmgr import wolfi` (meson build).
# TODO: REVIEWER — verify deps/outputs/runtime_deps + the build.sh opts.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let libxslt = import "../libxslt/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "20250605" in
{
  name = "iputils",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    libxslt,
    meson,
    ninja,
    pkgconf,
    toolchain,
    glibc,
    {
      url = "https://github.com/iputils/iputils/archive/refs/tags/%{version}.tar.gz",
      sha256 = "19e680c9eef8c079da4da37040b5f5453763205b4edfb1e2c114de77908927e4",
      extract = true,
      strip_prefix = "iputils-%{version}",
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
      source_provenance = { category = 'GithubRepo, owner = "iputils", repo = "iputils" },
      license_spdx = "BSD-3-Clause AND GPL-2.0-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # The Wolfi-ported block sent real ICMP echoes to loopback. Those
          # need CAP_NET_RAW, which the build sandbox does not grant, and the
          # importer also carried a leading `#` comment line into the command
          # itself. Version probes exercise the binaries without privileges.
          ["/bin/bash", "-c", "/bin/ping -V | grep -q iputils"],
          ["/bin/bash", "-c", "/bin/arping -V 2>&1 | grep -q iputils"],
        ],
      } | Test,
  },
} | BuildSpec
