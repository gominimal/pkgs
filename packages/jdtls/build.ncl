let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "1.63.0" in
let build_stamp = "202610191322" in
{
  name = "jdtls",
  # Eclipse JDT Language Server (Java). Universal jar distribution;
  # launched through the upstream bin/jdtls wrapper, which needs python
  # and a JDK (17+) at runtime.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://download.eclipse.org/jdtls/milestones/%{version}/jdt-language-server-%{version}-%{build_stamp}.tar.gz",
      sha256 = "b1f2abe0b3cccb462cf64fb4a5587c7d09df60cf8be7748b152cbd89d018bdc4",
    } | Source,
    base,
    tar,
  ],

  runtime_deps = [
    base,
    jdk,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include build_stamp,
  },

  outputs = {
    jdtls = { glob = "usr/bin/jdtls" } | OutputBin,
    install = { glob = "usr/share/jdtls/**", allow_data = true } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "EPL-2.0",
      binary_from = "https://download.eclipse.org/jdtls/milestones/",
      # Advisories for the JDT Language Server are filed against the SOURCE
      # repo, not the download mirror the binary comes from. Without this the
      # package is advisory-dark: no source can reach it, it scans 0/0/0 for an
      # infrastructural reason, and `coverage-health` fails the 08:05 job every
      # day (it did, 2026-09-02 through 09-11). Same class as jdk in pkgmgr#740.
      source_provenance = {
        category = 'GithubRepo,
        owner = "eclipse-jdtls",
        repo = "eclipse.jdt.ls",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/jdtls --help",
  },
} | BuildSpec
