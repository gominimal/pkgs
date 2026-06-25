let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "2.19.0" in

let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "e660e312df0faa8fe319a98bc19244f3b741c9e65576a1be20bd95ec03857dbc",
  arm64_sha256 = "48f523fefcf5f1b40954a6524ce70b6b540241d88a7043c40ec01e2832dd0a49",
}
in

{
  name = "edgedelta",

  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://release.edgedelta.com/v%{version}/edgedelta-linux-amd64.sh",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://release.edgedelta.com/v%{version}/edgedelta-linux-arm64.sh",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
  ],

  # The agent is a statically linked Go binary; ca-certificates is needed at
  # runtime so it can establish TLS connections to the Edge Delta cloud.
  runtime_deps = [ca-certificates],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/edgedelta" } | OutputBin,
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -x /usr/bin/edgedelta"],
          ["/bin/bash", "-c", "/usr/bin/edgedelta -v || /usr/bin/edgedelta -version || /usr/bin/edgedelta --help || true"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
