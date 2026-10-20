let { Attrs, BuildSpec, Local, Needs, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "0.12.23" in
{
  name = "uv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/uv-%{version}.tar.gz",
      sha256 = "662023e7453d40c2e751ddc9f0c9dc27e09f27324ca7e81249b3d15a5e5e364f"
    } | Source,
    base,
    make,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    minimal = { glob = "usr/bin/uv" } | OutputLib,
    config = { glob = "etc/uv/uv.toml" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      env_state_wiring = {
        env_var = "UV_CACHE_DIR",
        prefix = "uv-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "astral-sh",
        repo = "uv",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    # /etc/uv/uv.toml turns on system-certs, and the opt-outs still work:
    # --no-system-certs, a user uv.toml saying `system-certs = false`, and
    # UV_NO_SYSTEM_CONFIG. (UV_SYSTEM_CERTS=false is NOT one: uv only lets
    # the variable turn the setting on.) `--show-settings` prints the
    # resolved settings and exits before doing any work, so this needs no
    # network.
    system_certs =
      {
        class = 'Standalone,
        test_deps = [base, ca-certificates],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              unset UV_SYSTEM_CERTS UV_NATIVE_TLS UV_NO_SYSTEM_CONFIG XDG_CONFIG_DIRS
              export XDG_CONFIG_HOME="$(mktemp -d)"
              cd "$(mktemp -d)"
              uv cache dir --show-settings > on
              grep -q 'system_certs: true,' on
              uv cache dir --no-system-certs --show-settings > cli_off
              grep -q 'system_certs: false,' cli_off
              UV_NO_SYSTEM_CONFIG=1 uv cache dir --show-settings > no_config
              grep -q 'system_certs: false,' no_config
              mkdir -p "$XDG_CONFIG_HOME/uv"
              echo 'system-certs = false' > "$XDG_CONFIG_HOME/uv/uv.toml"
              uv cache dir --show-settings > user_off
              grep -q 'system_certs: false,' user_off
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
