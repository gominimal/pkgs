let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let curl = import "../curl/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in
let zig = import "../zig/build.ncl" in

let version = "0.3.0" in
# The zig packages `zig build` resolves for tmd 0.3.0, each checked in build.sh
# against the content hash its parent build.zig.zon pins. ghostty runs its whole
# build.zig as a dependency (in -Demit-lib-vt mode), so lazy dependencies it
# never links into tmd are still resolved: the iTerm2 themes (emit-themes
# defaults on), zlib (for the host-side framegen tool) and the wuffs test
# images. -D options reach only the root package, so tmd cannot switch them off.
# Same set herdr measured for libghostty-vt (5354af3d), minus highway (tmd
# passes simd = false). On a tmd or ghostty bump: re-derive from the new zon
# files and re-mirror what changed.
#   ghostty 1.4.0          tmd's build.zig.zon (lazy)
#   uucode, iterm2_themes  ghostty's build.zig.zon
#   translate_c            ghostty's pkg/translate-c
#   aro                    translate_c's zon pins git+https://codeberg.org/ziglang/arocc
#                          #d0c8c4d9; mirrored from codeberg's archive of that commit
#                          (zig's package hash covers file contents only)
#   zlib                   ghostty's pkg/zlib
#   wuffs, pixels          ghostty's pkg/wuffs
let zig_dep = fun file sha =>
  {
    url = "gs://minimal-staging-archives/tmd/zig-deps/%{file}",
    sha256 = sha,
  } | Source
in
let zig_deps = [
  # ghostty itself: upstream's tag archive, not mirrored.
  {
    url = "https://github.com/ghostty-org/ghostty/archive/refs/tags/v1.4.0.tar.gz",
    sha256 = "2e2a2516f9bea89a4991ad7c9401b77682eed366387a5b1d7c629472b5d11a43",
  } | Source,
  zig_dep "uucode-ea62149739404a73c202b48a33bf6dd2af4bd9b0.tar.gz" "f37c4071a217853450d084cb9c12b6d4b68f887eb9cb42fe77a84f86056eacbf",
  zig_dep "ghostty-themes-release-20261019-151001-86a776d.tgz" "ab2513e316372c45c9f86e3e511aebdbfa6c39fa03c210096b19152fe288505b",
  zig_dep "translate_c-02ff0c523fb92a38939b04d0145c4a9602a74d56.tar.gz" "e344433bcce14759529e58ea600e67d7c39846b1775b122f88db7cb4dad58591",
  zig_dep "arocc-d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b.tar.gz" "42f5ac4d1fb7c55ad4073dc462b02d485ace4da6d7fc29b35acfa99e28f2cb7d",
  zig_dep "zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz" "17e88863f3600672ab49182f217281b6fc4d3c762bde361935e436a95214d05c",
  zig_dep "wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz" "17877d346f7988651d6c62e45b2e3b05c86809a6442c5e34612374b2a9719a1c",
  zig_dep "pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz" "55e83b16d091082502bf149bf457f31f42092c5982650e3ffbae7b48871bf11a",
]
in
{
  name = "tmd",
  # Terminal Markdown viewer, built from source with the zig package.
  #
  # Offline: every zig package the build resolves is pinned (`zig_deps` above),
  # and build.sh unpacks each into zig-pkg/<hash>/ once `zig fetch <file>` has
  # checked it against the content hash the upstream build.zig.zon pins.
  # There is no `needs`, so the sandbox has no network: a missing package fails
  # the build instead of being downloaded (pkgs#1545 lost an amd64 world build
  # to a ConnectionResetByPeer from deps.files.ghostty.org).
  build_deps =
    [
      { file = "build.sh" } | Local,
      {
        url = "https://github.com/jtnk/tmd/archive/refs/tags/v%{version}.tar.gz",
        sha256 = "41f8c26c3358b80a769ea5e9974494167674303bc3e493a8c4f6082a316df642",
        extract = true,
        strip_prefix = "tmd-%{version}",
      } | Source,
      base,
      zig,
    ]
    @ zig_deps,

  # The binary is static (see build.sh), so there is no libc here. It runs curl
  # to load URLs, and draws large headings with a bold font from
  # /usr/share/fonts. Without these it still works, with those features off.
  runtime_deps = [curl, liberation-fonts],

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
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "printf '# Title\\n\\n**bold** text\\n' | tmd -p | grep -q 'bold text'"],
        ],
      } | Test,
    notices =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
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
