# mtools — packaging notes

## Version + source

- Version: **4.0.49** (latest GNU release as of 2026-05).
- Source: `https://ftp.gnu.org/gnu/mtools/mtools-4.0.49.tar.gz`
- sha256: `10cd1111da87bf2400a380c1639a6cba8bfb937a24f9c51f5f88d393ae5f6f76`
  (downloaded and hashed locally; pinned in `build.ncl`).

## Configure flags

```
./configure --prefix=/usr --disable-floppyd --without-x
```

- `--prefix=/usr` → installs the single `mtools` binary plus its command symlinks
  (`mmd`, `mcopy`, `mformat`, `mattrib`, `mdir`, `mlabel`, `minfo`, …) into `/usr/bin`,
  caught by the `bins = { glob = "usr/bin/*" }` output.
- `--disable-floppyd` / `--without-x`: `floppyd` is the only X11-dependent component.
  Disabling it keeps the runtime dependency set down to `glibc` alone.

## Dependencies

- build_deps: `base-bootstrap`, `make`, `toolchain` (matches the autotools C template).
- runtime_deps: `glibc`.
- **iconv**: mtools can optionally link `libiconv` for codepage/charset conversion.
  On glibc this is provided by the C library itself, so no separate `libiconv`
  package is needed (none exists in the registry). Nothing missing.
- No other optional deps enabled.

## Verification status

- Confirmed locally (on macOS host): `configure` succeeds, `make` builds clean,
  `mtools --version` reports `4.0.49`, and the `mformat`/`mmd`/`mcopy` FAT-image
  roundtrip used by the smoke test passes.
- **Could not run the minimal sandbox build** (Linux/glibc) from this environment,
  so the package has not been built against the real `base-bootstrap`/`toolchain`/
  `glibc` deps in-sandbox. CFLAGS/LDFLAGS/configure flags mirror the existing
  autotools C packages (util-linux, bc, gzip).

## PR-body draft

> Adds an `mtools` package (GNU mtools 4.0.49) to the pkgs registry. mtools provides
> `mmd`/`mcopy`/`mformat`, which let us populate a FAT EFI System Partition image
> without loop-mounting (useful for building bootable images in unprivileged sandboxes).
> Standard autotools build: `./configure --prefix=/usr --disable-floppyd --without-x`,
> then `make DESTDIR=$OUTPUT_DIR install`. Deps: base-bootstrap, make, toolchain (build),
> glibc (runtime); iconv is satisfied by glibc. Source pinned to the GNU FTP tarball with
> a locally computed sha256. Includes a `--version` smoke test plus an mmd/mcopy FAT
> roundtrip test (both validated locally).
