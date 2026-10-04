let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026e" in
{
  name = "tzdata",
  # No `base` here: `base` carries tzdata at runtime, so building tzdata against it would be a cycle.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://data.iana.org/time-zones/releases/tzdata%{version}.tar.gz",
      sha256 = "b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652",
      extract = true,
    } | Source,
    bash-bootstrap,
    coreutils,
    glibc, # zic
  ],

  cmd = "./build.sh",

  outputs = {
    zoneinfo = { glob = "usr/share/zoneinfo/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LicenseRef-Public-Domain",
      repology_project = "tzdata",
    } | Attrs,

  tests = {
    tz_resolves =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/share/zoneinfo/UTC"],
          ["/bin/bash", "-c", "[[ $(TZ=America/Vancouver date +%Z) == P[SD]T ]]"],
          ["/bin/bash", "-c", "test \"$(TZ=Europe/Paris date -d @0 +%H)\" = 01"],
        ],
      } | Test,
  },
} | BuildSpec
