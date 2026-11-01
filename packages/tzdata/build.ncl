let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2026f" in
{
  name = "tzdata",
  # No `base` here: `base` carries tzdata at runtime, so building tzdata against it would be a cycle.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://data.iana.org/time-zones/releases/tzdata%{version}.tar.gz",
      sha256 = "01b4a91cec5167ed48c11e8ab78f2048cead78ce94b0cafcad0ae8c5a3044d3d",
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
      # The tz project's own repository (IANA's tz coordinator publishes there; its tags match
      # this version, e.g. 2026e). Gives the package an advisory identity: NVD has no CPE for the
      # tz database under any vendor, so without this it was unmonitorable (pkgmgr coverage gap).
      # The download stays on data.iana.org above; provenance only drives advisory/version lookups.
      source_provenance = {
        category = 'GithubRepo,
        owner = "eggert",
        repo = "tz",
      },
    } | Attrs,

  tests = {
    tz_resolves =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/share/zoneinfo/UTC"],
          # Pinned instants, not "now": British Columbia moved to permanent UTC-7 at
          # 2026-11-01T09:00Z and tzdata calls it MST from then on, so asserting today's
          # abbreviation broke every PR's checks that morning. These two still prove the
          # zone and its DST rules resolve: 2025-01-15 is PST, 2025-07-15 is PDT.
          ["/bin/bash", "-c", "test \"$(TZ=America/Vancouver date -d @1736899200 +%Z)\" = PST"],
          ["/bin/bash", "-c", "test \"$(TZ=America/Vancouver date -d @1752537600 +%Z)\" = PDT"],
          ["/bin/bash", "-c", "test \"$(TZ=Europe/Paris date -d @0 +%H)\" = 01"],
        ],
      } | Test,
  },
} | BuildSpec
