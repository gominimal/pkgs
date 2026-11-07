let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in
let zig = import "../zig/build.ncl" in

let version = "0.2.0" in
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
      sha256 = "3ca9a15d02e4d969394a72e63491fc73b6cc1a9ee505aff791c3c9a49b8a186d",
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
    # LICENSE (tmd, Apache-2.0) and upstream's THIRD_PARTY_NOTICES.md: the static binary
    # carries ghostty-vt, uucode, Unicode data, NanoSVG, stb, the Zig standard library
    # and musl, whose MIT / Zlib / Unicode-3.0 terms require the notices to travel with it.
    licenses = { glob = "usr/share/licenses/tmd/*" } | OutputData,
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
    notices =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "grep -q 'Apache License' /usr/share/licenses/tmd/LICENSE"],
          ["/bin/bash", "-c", "grep -q '^## musl' /usr/share/licenses/tmd/THIRD_PARTY_NOTICES.md && grep -q '^## Ghostty' /usr/share/licenses/tmd/THIRD_PARTY_NOTICES.md"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      # tmd is Apache-2.0; the static binary also compiles in ghostty-vt, uucode, the Zig
      # standard library and musl (MIT), NanoSVG (Zlib), Unicode data (Unicode-3.0) and
      # stb_image / stb_truetype (MIT or public domain, Unlicense). Upstream's
      # THIRD_PARTY_NOTICES.md lists each; it is installed under usr/share/licenses/tmd.
      license_spdx = "Apache-2.0 AND MIT AND Zlib AND Unicode-3.0 AND (MIT OR Unlicense)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "jtnk",
        repo = "tmd",
      },
    } | Attrs,
} | BuildSpec
