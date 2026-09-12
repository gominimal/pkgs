let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let python = import "../python/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "1.60.0" in
let build_stamp = "202606262232" in
{
  name = "jdtls",
  # Eclipse JDT Language Server (Java). Universal jar distribution;
  # launched through the upstream bin/jdtls wrapper, which needs python
  # and a JDK (17+) at runtime.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://download.eclipse.org/jdtls/milestones/%{version}/jdt-language-server-%{version}-%{build_stamp}.tar.gz",
      sha256 = "e94c303d8198f977930803582738771fd18c52c5492878410bf222b1aa81ef1d",
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
    } | Attrs,
} | BuildSpec
