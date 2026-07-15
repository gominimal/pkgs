# Licensing

This repository contains two distinct kinds of material, under two distinct
licensing regimes. This document states which is which.

## 1. The build recipes — Apache-2.0

Everything *authored in this repository* — the package build specifications
(`packages/*/build.ncl`), build scripts (`packages/*/build.sh`, patches,
helper files), CI workflows, and tooling — is licensed under the
[Apache License, Version 2.0](LICENSE), like the rest of the repository.

A small number of packages (for example `minimal-sshd`) are programs whose
*source code itself* lives in this repository; those are likewise Apache-2.0
and declare it in their `license_spdx`.

## 2. The packaged software — its own upstream license

Each package built from these recipes packages **someone else's software**,
and that software remains under **its own upstream license**. Building or
distributing a package through this repository's infrastructure does not
relicense it.

Every package declares its upstream license as an [SPDX
expression](https://spdx.org/licenses) in its build specification:

```nickel
attrs = {
  license_spdx = "GPL-3.0-or-later",
} | Attrs,
```

Packages without a single meaningful upstream license use either:

- an SPDX expression (`(LGPL-2.1-only AND GPL-2.0-only)`) when the artifact
  combines materials under several licenses;
- a `LicenseRef-*` identifier for software that is not under an open-source
  license at all (for example `LicenseRef-Anthropic-Proprietary`) — such
  packages may carry redistribution restrictions beyond what this document
  covers.

A few *internal aggregate* packages (`base`, `toolchain`, …) compose many
other packages and intentionally declare no single license; their contents
are governed by the licenses of the packages they aggregate.

## 3. Distribution: the binary cache and the source mirror

Binaries built from these recipes are distributed through a binary cache,
and the source archives they are built from are mirrored (see
`gs://minimal-staging-archives`). License obligations — carrying copyright
notices and license texts, and for copyleft licenses providing the
corresponding source — attach at that distribution point. The source mirror
holds the exact, content-addressed archives each binary was built from and
serves as the corresponding-source offer for copyleft packages.

Questions about a specific package's license belong on the package (check
its `license_spdx` and upstream project) — questions about *this
repository's* license terms belong with the [LICENSE](LICENSE) file and the
CLAs under [`legal/`](legal/).
