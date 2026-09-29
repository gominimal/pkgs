# packages/rustc-1.94.1

Builds rustc 1.94.1 (with cargo and std) from the upstream `rustc-1.94.1-src.tar.xz`, using the
`rustc-1.93.1` package as x.py's stage0, with no network access, and installs it to the private prefix
`/usr/lib/rustc-1.94.1` (`bin/`, `lib/` and `BUILDINFO` only). `rustc-1.95.0` consumes that prefix as its
stage0 the same way.

## Stage0 wiring

`build.sh` generates `bootstrap.toml` with `[build] rustc`/`cargo` pointing at
`/usr/lib/rustc-1.93.1/bin/{rustc,cargo}`, so x.py uses those binaries instead of downloading the
`src/stage0` snapshot. Before building it asserts the stage0 runs (`--version` contains 1.93.1,
`--print sysroot` equals the prefix) and that the extracted source is the right one
(`src/version` is 1.94.1 and `src/stage0` pins the stage0's version).

## Offline mechanism

- Crates: the source tarball ships `.cargo/config.toml` redirecting crates-io to its bundled `vendor/`.
- Stage0 download: disabled by the `[build] rustc`/`cargo` pins.
- LLVM: external `llvm-config = /usr/bin/llvm-config` (packages/llvm, LLVM 21) with `[llvm] link-shared`.
- `curl`/`wget`: stubs that exit non-zero and record a tripwire. `git`: a stub that allows local
  read-only verbs and fails on network verbs.
- Vendored `curl-sys`/`libssh2-sys`: an empty `.git` marker in each bundled submodule dir keeps
  their `build.rs` from running `git submodule update --init`.
- An ambient `.cargo/` above the build root fails the build, since cargo would merge it.

## Gates (run on the installed binaries)

1. `rustc --version` contains 1.94.1.
2. An rlib is emitted.
3. Ten std constructs compile and run; the exit code is their computed sum (42), each with its own failure code (111-120).
4. A proc-macro crate is built as a dylib, loaded and expanded by rustc, and the result runs (42).
5. cargo builds a proc-macro crate plus a `#[derive]` consumer offline, and the binary runs (42).
6. `bin/rustc` has a glibc interpreter and the network tripwire is still clean.

## Files

| file | role |
|---|---|
| `build.ncl` | spec: stage0 build_dep, source, system LLVM, one `OutputData` glob over `usr/lib/rustc-1.94.1/**`; empty on arm64 |
| `build.sh` | preconditions, offline stubs, submodule markers, `bootstrap.toml`, `x.py build`, install, gates, seal |
| `gatelib.rs`, `gatestd.rs`, `gate_pm.rs`, `gate_pm_use.rs` | readable copies of the gate sources heredoc'd in `build.sh` |
| `rustc-1.94.1.answers` | sha256 pins for `bin/rustc` and `bin/cargo`; none yet, so the seal check is skipped |

Per-rung values: `VERSION`/`STAGE0_VERSION` in `build.sh`; `version`, `stage0_version`, the stage0
import and the Source `sha256` in `build.ncl`; the `.answers` filename and its two pin paths.

1.95.0's bootstrap needs `proc_macro::tracked_env`, present in 1.94.1 but not in 1.94.0, which is
why the ladder passes through 1.94.1.
