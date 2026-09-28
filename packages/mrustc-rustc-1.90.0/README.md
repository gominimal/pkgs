# packages/mrustc-rustc-1.90.0

Builds rustc 1.90.0 + cargo + libstd with the `mrustc`/`minicargo` binaries from
`packages/mrustc`, offline, using the `gcc-15.2.0-glibc` toolchain and the
`glibc-bedrock-2.42` sysroot. Installs to the private prefix `usr/lib/mrustc-rust-1.90.0/`
so it does not collide with `packages/rust`; the `rustc-1.91.1` recipe consumes it as stage0.

## Inputs

| Source | Role |
|---|---|
| `rustc-1.90.0-src.tar.gz` | rustc source incl. `vendor/` and `src/llvm-project`. Must be `.tar.gz`: `minicargo.mk:220` hardcodes the name and `:226` runs `tar -xzf`. |
| `mrustc-0.12.0-git1d552ca.tar` | Same bytes as `packages/mrustc`'s Source. Used as data only: `minicargo.mk`, `run_rustc/`, `rustc-1.90.0-src.patch`, `script-overrides/`, `lib/libproc_macro`. `make -f Makefile all` is never run. |

The compiler binaries come from `packages/mrustc`'s rootfs. `minicargo.mk:39/:41` declare
`MRUSTC`/`MINICARGO` with `?=` and use them as file prerequisites, so pointing them at the
installed binaries leaves the `.PHONY` self-rebuild rules unreferenced. `$(MRUSTC)` is
prerequisite-only on the build path; minicargo picks the compiler via `MRUSTC_PATH`
(`os.cpp:419`), which `build.sh` exports and checks with `mrustc -vV`.

## Build (`build.sh`)

P0 preconditions, P0b offline stubs, P1 unpack + compiler wrappers, P2 rustc source
(`make RUSTCSRC`, `.git` submodule markers, `archive-zerolen-skip.sh`), P3 LLVM via cmake
(`CC`/`CXX` passed on the make command line because `minicargo.mk:301` reads the make
builtins), P4 `LIBS` -> `output-1.90.0/rustc` -> `output-1.90.0/cargo`, P5 `run_rustc`
stages 1-4, P6 install (the `bin/rustc` wrapper is regenerated `$0`-relative; the tree is
swept for build paths), P7 gates, P8 byte seal.

Offline: curl/wget stubs fail; the git stub allows only local probes (`rev-parse HEAD`,
`--git-dir`, `--show-toplevel`, `--version`) and fails any other argv. `CARGO_NET_OFFLINE`
and `GIT_CEILING_DIRECTORIES` are exported. minicargo cannot fetch and `vendor/` covers all
four lockfiles.

## Gates (run on the installed binaries)

| Gate | Checks |
|---|---|
| 1 | `rustc --version` contains `1.90.0-stable-mrustc` |
| 2 | `gatelib.rs` builds as an rlib (exercises `ArArchiveBuilder`) |
| 3 | `gate190.rs`: ten std constructs compiled and run, computed exit 42, per-construct codes 111-120, cross-crate call into the rlib |
| 4 | `gate_pm.rs` builds as a proc-macro dylib; `gate_pm_use.rs` loads it and runs (dylib std + `proc_macro`) |
| 5 | cargo builds a two-crate path-dependency workspace offline |
| 6 | both compiler wrappers were used, LLVM went through the C++ wrapper, `rustc_binary` uses the sysroot loader |
| 7 | network tripwire still clean after the gates |

The shipped rustc carries two patches, both recorded in `BUILDINFO`: mrustc's
`rustc-1.90.0-src.patch` (`minicargo.mk:229`) and `archive-zerolen-skip.sh`.
`rustc-1.90.0.answers` holds the byte-seal pins; the check arms when pin lines are present.
