let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let rust = import "../rust/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let git = import "../git/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "4.8.1" in
{
  name = "fish",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/fish-shell/fish-shell/releases/download/%{version}/fish-%{version}.tar.xz",
      sha256 = "0eb86a851e865e934a7c2091a73d7695225e78f0e00a7bb96d5f877d76c65782",
      extract = true,
      strip_prefix = "fish-%{version}",
    } | Source,
    base,
    toolchain,
    rust,
    cmake,
    ninja,
    git,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    pcre2,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    fish = { glob = "usr/bin/fish" } | OutputBin,
    fish_indent = { glob = "usr/bin/fish_indent" } | OutputBin,
    fish_key_reader = { glob = "usr/bin/fish_key_reader" } | OutputBin,

    # fish 4.x (Rust rewrite) embeds completions/functions/config.fish into the
    # binary — they are no longer installed as files under usr/share/fish/.
    docs = { glob = "usr/share/doc/fish/**" } | OutputData,
    pkgconfig = { glob = "usr/share/pkgconfig/fish.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "fish-shell",
        repo = "fish-shell",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/fish", "--version"],
        ],
      } | Test,
    basic_echo =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/fish", "-c", "echo hello"],
        ],
      } | Test,
    math =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/fish", "-c", "math 2 + 2"],
        ],
      } | Test,
  },
} | BuildSpec
