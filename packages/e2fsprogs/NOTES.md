# e2fsprogs packaging notes

## Version + SHA

- **Version**: `1.47.4` (current stable; latest on the canonical tytso mirror at packaging time).
- **Source URL**: `https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.4/e2fsprogs-1.47.4.tar.xz`
- **sha256**: `fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b`
  - Computed locally via `curl ... | shasum -a 256` against the real downloaded tarball (7.0 MiB).

## configure flags rationale

```
--bindir=/usr/bin --sbindir=/usr/sbin --libdir=/usr/lib --enable-elf-shlibs --disable-defrag --without-libintl-prefix
```

- `--bindir/--sbindir/--libdir`: e2fsprogs derives its `root_bindir/root_sbindir/root_libdir`
  (where `mke2fs`, `mkfs.ext4`, `fsck.ext4`, the shared libs, etc. install) from these. Setting all three
  explicitly lands the entire install tree under `/usr` — verified by inspecting `config.status`
  (`root_sbindir=/usr/sbin`, `root_libdir=/usr/lib`, `root_bindir=/usr/bin`). No `--with-root-prefix` needed.
- `--enable-elf-shlibs`: builds the shared `libext2fs`, `libcom_err`, `libe2p`, `libss`, `libuuid`,
  `libblkid` we ship as `OutputLib`.
- `--disable-defrag`: e4defrag is not needed for building ext4 images and pulls extra surface; matches the
  minimal philosophy of the registry.
- `--without-libintl-prefix`: don't search host dirs for an external libintl (gettext) — keep the build
  self-contained against `glibc` only.
- e2fsprogs **has no `--disable-static` flag** (unlike util-linux/acl). It always emits `.a` archives.
  We simply do not glob them (`usr/lib/lib*.so*` only), so they aren't captured as outputs.
- `--enable-libuuid` / `--enable-libblkid` are **on by default** — e2fsprogs builds and uses its own private
  uuid/blkid libs, so we don't depend on util-linux's copies. Left at defaults.

## Outputs

- `usr/bin/*` and `usr/sbin/*` as `OutputBin` (covers `mke2fs`, `mkfs.ext2/3/4`, `fsck.ext2/3/4`, `e2fsck`,
  `tune2fs`, `dumpe2fs`, `resize2fs`, `debugfs`, `badblocks`, `findfs`, plus `chattr`/`lsattr`/`uuidgen` in
  `/usr/bin`). Glob style modeled on util-linux.
- Per-lib `OutputLib` globs for `libext2fs`, `libcom_err`, `libe2p`, `libss`, `libuuid`, `libblkid`, plus a
  catch-all `usr/lib/lib*.so*`.

## Missing deps

- None. `base-bootstrap`, `make`, `toolchain`, and `glibc` are all present in the registry. `tar` (needed for
  manual extraction in build.sh) is supplied transitively by `base-bootstrap`.

## Build-verification status

- **NOT built in the Minimal sandbox** — I cannot run `min` / the Linux sandbox build from this environment.
- Did verify on the host (macOS): tarball download + sha256, `./configure` succeeds with the chosen flags,
  install dirs resolve under `/usr` (via `config.status`), and the source's Makefiles confirm the
  sbin/bin/lib program + library layout the output globs target. The actual ELF compile/link only runs in the
  Linux sandbox (it cannot link ELF shlibs on Darwin, as expected).
- Source-extraction is done manually in `build.sh` (`tar -xof`), mirroring util-linux, rather than via the
  `Source` `extract`/`strip_prefix` fields.

## PR-body draft

> Adds an `e2fsprogs` package (v1.47.4) so the registry can build ext4 images via `mke2fs -d`.
> Follows the util-linux autotools template: `base-bootstrap` + `make` + `toolchain` build deps, `glibc`
> runtime dep, manual tarball extraction in `build.sh`, and `make DESTDIR=$OUTPUT_DIR install`.
> Configured with `--enable-elf-shlibs --disable-defrag --without-libintl-prefix` and explicit
> `--bindir/--sbindir/--libdir` so the whole tree lands under `/usr`. Outputs the `mke2fs`/`mkfs.ext4`
> family under `usr/sbin` plus the e2fsprogs shared libs (`libext2fs`, `libcom_err`, `libe2p`, `libss`,
> `libuuid`, `libblkid`). sha256 pinned from the canonical tytso kernel.org mirror.
> Not yet built in the sandbox — needs a CI/sandbox build to confirm.
