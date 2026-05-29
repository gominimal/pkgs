# dosfstools — packaging notes

## Version & source

- Version: **4.2**
- URL: `https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz`
- sha256: `64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527`
  (computed by curling the real release tarball, not copied from elsewhere)

## configure flags

```
./configure --prefix=/usr --sbindir=/usr/sbin --enable-compat-symlinks
```

- `--enable-compat-symlinks` makes `make install` create the legacy aliases in
  `/usr/sbin`: `mkfs.vfat`, `mkfs.msdos`, `mkdosfs` (-> `mkfs.fat`), `fsck.vfat`,
  `fsck.msdos`, `dosfsck` (-> `fsck.fat`), and `dosfslabel` (-> `fatlabel`).
  This is why the family `{ glob = "usr/sbin/*" }` output picks up `mkfs.vfat`.
- Real binaries installed (from `src/Makefile.am sbin_PROGRAMS`): `mkfs.fat`,
  `fsck.fat`, `fatlabel`.

## Dependencies

Kept minimal per the autotools template: `base-bootstrap`, `make`, `toolchain`,
`glibc` (runtime). No missing registry deps.

- iconv: configure detects `--with-iconv` automatically; on glibc, `iconv` is
  built into libc, so no separate `libiconv` package is needed (nothing extra to
  add to the registry).

## Could not run the minimal sandbox build

This work was done on a macOS host with no access to the minimal Linux build
sandbox, so I could not produce the real package artifact. I did validate locally
that:

- the release tarball downloads and its sha256 matches the pin;
- `./configure --prefix=/usr --sbindir=/usr/sbin --enable-compat-symlinks`
  completes successfully;
- `src/Makefile.am` confirms the installed sbin programs and the compat symlinks.

The subsequent `make` fails *on macOS only* because `device_info.c` includes the
Linux-only header `<sys/sysmacros.h>` — expected, since this package targets
Linux/glibc and will compile in the sandbox.

## PR-body draft

> Adds a `dosfstools` package (v4.2) providing `mkfs.fat`/`mkfs.vfat` for
> formatting the FAT EFI System Partition. Standard autotools build
> (`./configure --prefix=/usr --sbindir=/usr/sbin --enable-compat-symlinks`),
> deps limited to `base-bootstrap`, `make`, `toolchain`, and `glibc` at runtime.
> Source pinned to the upstream GitHub release tarball with a verified sha256.
> Outputs expose `mkfs.fat` individually plus the full `usr/sbin/*` family
> (compat symlinks included). Not built in the Linux sandbox from this host;
> configure + sha256 verified locally.
