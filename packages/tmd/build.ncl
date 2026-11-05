let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in
let zig = import "../zig/build.ncl" in

let version = "0.1.0" in
{
  name = "tmd",
  # Terminal Markdown viewer, built from source with the zig package.
  #
  # Needs network: `zig build` fetches the dependencies declared in
  # build.zig.zon (ghostty and what it pulls in), each verified against the
  # content hash pinned in that file.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jtnk/tmd/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6b3ac72c5f8839343b5386781dc9c522334e8d9509948daf64f1f04b0b546065",
      extract = true,
      strip_prefix = "tmd-%{version}",
    } | Source,
    base,
    zig,
  ],

  # The binary is static (see build.sh), so there is no libc here. It runs curl
  # to load URLs, and draws large headings with a bold font from
  # /usr/share/fonts. Without these it still works, with those features off.
  runtime_deps = [curl, liberation-fonts],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    tmd = { glob = "usr/bin/tmd" } | OutputBin,
  },

  tests = {
    version = standaloneTest "tmd --version",
    render =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf '# Title\\n\\n**bold** text\\n' | tmd -p | grep -q 'bold text'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "jtnk",
        repo = "tmd",
      },
    } | Attrs,
} | BuildSpec
