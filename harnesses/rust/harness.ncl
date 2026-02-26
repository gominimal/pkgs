let { harness, .. } = import "minimal.ncl" in
harness {
  name = "rust",

  build_packages = ["gcc", "rust", "binutils", "pkgconf"],
  build_env_vars = {
    # The 'env_state_wiring' attribute on the 'rust' package already wires a
    # state directory `cargo`, set to `$CARGO_HOME`. As such, we set the
    # location for storing built packages to `$CARGO_HOME/build`, so incremental
    # artifacts are stored in the state dir.
    CARGO_BUILD_BUILD_DIR = "{cargo-cache-home}/build",

    # Environment variables that configure the compiler/linker
    CC = "gcc",
    CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER = "gcc",
  },

  build_cmd = "cargo build --release",

  matches_project_if_any = [
    {
      file_regexes."Cargo.toml" = "*",

      build_package_if_any."protobuf" = [
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.\"prost-build\"",
        }
      ],

      runtime_package_if_any."openssl" = [
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.reqwest.features | contains(\"native-tls\")",
        },
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.\"openssl-sys\"",
        }
      ],
      runtime_package_if_any."bzip2" = [
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.bzip2.features | contains(\"bzip2-sys\")",
        }
      ],
      runtime_package_if_any."zstd" = [
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.zstd",
        }
      ],
      runtime_package_if_any."zlib" = [
        {
          file_predicates."Cargo.toml" = ".workspace.dependencies.flate2.features | any(. == \"zlib\" or . == \"zlib-default\" or . == \"cloudflare_zlib\")",
        }
      ],
    }
  ],
}
