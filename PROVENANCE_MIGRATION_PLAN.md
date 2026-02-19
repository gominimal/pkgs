# Source Provenance Migration Plan

## Overview

Add `source_provenance` metadata to all compatible packages in `gominimal/pkgs`. Currently only 3 of 193 packages have this field. This plan covers migrating the remaining ~155 eligible packages.

## Background

The `source_provenance` attribute in `attrs` declares the authoritative source of a package's source code. It's validated by the schema in `minpkgs/crates/graph/minimal-ncl/attr_classes.ncl` and consumed downstream for SBOM generation, provenance attestation, and supply-chain tracking.

### Supported Categories

**`'GithubRepo`** — for projects hosted on GitHub:
```nickel
source_provenance = {
  category = 'GithubRepo,
  owner = "Kitware",
  repo = "CMake",
  releases = 'TagBased {},  # optional
},
```

**`'GnuProject`** — for GNU project software:
```nickel
source_provenance = {
  category = 'GnuProject,
  name = "glibc",
},
```

### Current State

| Status | Count |
|--------|-------|
| Already has provenance | 3 (cmake, glibc, tailscale) |
| Eligible: GithubRepo | ~120 |
| Eligible: GnuProject | ~35 |
| Meta/no-source (skip) | 5 |
| Other/unclear (skip) | ~18 |
| Borderline GitLab etc (skip for now) | ~12 |

---

## Migration Strategy

### Phase 1: GNU Projects (35 packages)

Straightforward — each is a well-known GNU project. The `name` field matches the GNU project identifier.

**Pattern**: Add `source_provenance` to existing `attrs` block, or expand shorthand `attrs.upstream_version` to a full `attrs = { ... } | Attrs` block.

**Packages:**

| Package | GNU name |
|---------|----------|
| `autoconf` | autoconf |
| `automake` | automake |
| `bash` | bash |
| `bc` | bc |
| `binutils` | binutils |
| `bison` | bison |
| `coreutils` | coreutils |
| `dejagnu` | dejagnu |
| `diffutils` | diffutils |
| `gawk` | gawk |
| `gcc` | gcc |
| `gdbm` | gdbm |
| `gettext` | gettext |
| `gmp` | gmp |
| `gperf` | gperf |
| `grep` | grep |
| `groff` | groff |
| `gzip` | gzip |
| `inetutils` | inetutils |
| `libidn2` | libidn2 |
| `libtool` | libtool |
| `libunistring` | libunistring |
| `m4` | m4 |
| `make` | make |
| `mpc` | mpc |
| `mpfr` | mpfr |
| `nano` | nano |
| `ncurses` | ncurses |
| `patch` | patch |
| `readline` | readline |
| `screen` | screen |
| `sed` | sed |
| `tar` | tar |
| `time` | time |
| `wget` | wget |

### Phase 2: GitHub Repos — GCS owner/repo pattern (53 packages)

These have source URLs like `gs://minimal-staging-archives/{owner}/{repo}/...` — the owner/repo is extracted using the same GCS URL regex that `pkgmgr` uses (`gcsURLRe` in `manager.go`).

| Package | Owner | Repo |
|---------|-------|------|
| `age` | FiloSottile | age |
| `atuin` | atuinsh | atuin |
| `bat` | sharkdp | bat |
| `biff` | BurntSushi | biff |
| `bottom` | ClementTsang | bottom |
| `brush` | reubeno | brush |
| `btop` | aristocratos | btop |
| `caddy` | caddyserver | caddy |
| `clipper2` | AngusJohnson | Clipper2 |
| `cosign` | sigstore | cosign |
| `delta` | dandavison | delta |
| `difftastic` | Wilfred | difftastic |
| `duf` | muesli | duf |
| `dust` | bootandy | dust |
| `eza` | eza-community | eza |
| `fd` | sharkdp | fd |
| `fzf` | junegunn | fzf |
| `gh` | cli | cli |
| `glow` | charmbracelet | glow |
| `grpcurl` | fullstorydev | grpcurl |
| `grype` | anchore | grype |
| `helix` | helix-editor | helix |
| `hexhog` | DVDTSB | hexhog |
| `hex-patch` | Etto48 | HexPatch |
| `htop` | htop-dev | htop |
| `hwdata` | vcrhonek | hwdata |
| `imgcatr` | SilinMeng0510 | imgcatr |
| `jaq` | 01mf02 | jaq |
| `jnv` | ynqa | jnv |
| `jqfmt` | noperator | jqfmt |
| `libuv` | libuv | libuv |
| `llama.cpp` | ggml-org | llama.cpp |
| `manifold` | elalish | manifold |
| `mermaid-ascii` | AlexanderGrooff | mermaid-ascii |
| `meson` | mesonbuild | meson |
| `ninja` | ninja-build | ninja |
| `nushell` | nushell | nushell |
| `onetbb` | uxlfoundation | oneTBB |
| `openblas` | OpenMathLib | OpenBLAS |
| `openssl` | openssl | openssl |
| `prek` | j178 | prek |
| `procs` | dalance | procs |
| `pulumi` | pulumi | pulumi |
| `railway` | railwayapp | cli |
| `redis` | redis | redis |
| `ripgrep` | BurntSushi | ripgrep |
| `skopeo` | containers | skopeo |
| `syft` | anchore | syft |
| `terraform` | hashicorp | terraform |
| `tmux` | tmux | tmux |
| `trivy` | aquasecurity | trivy |
| `ut` | ksdme | ut |
| `yazi` | sxyazi | yazi |
| `zellij` | zellij-org | zellij |

### Phase 3: GitHub Repos — Direct GitHub URLs (19 packages)

These download directly from `github.com/{owner}/{repo}/...` — the owner/repo is extracted using pkgmgr's GitHub URL regex (`urlFieldRe` in `manager.go`).

| Package | Owner | Repo |
|---------|-------|------|
| `abseil-cpp` | abseil | abseil-cpp |
| `bash-completions` | scop | bash-completion |
| `bun` | oven-sh | bun |
| `bzip3` | iczelia | bzip3 |
| `cython` | cython | cython |
| `deno` | denoland | deno |
| `ghostscript` | ArtifexSoftware | ghostpdl-downloads |
| `icu` | unicode-org | icu |
| `jdk` | adoptium | temurin21-binaries |
| `libevent` | libevent | libevent |
| `libsodium` | jedisct1 | libsodium |
| `libssh2` | libssh2 | libssh2 |
| `libxml2` | GNOME | libxml2 |
| `libxslt` | GNOME | libxslt |
| `libyaml` | yaml | libyaml |
| `nghttp2` | nghttp2 | nghttp2 |
| `oniguruma` | kkos | oniguruma |
| `openjpeg` | uclouvain | openjpeg |
| `patchelf` | NixOS | patchelf |
| `protobuf` | protocolbuffers | protobuf |

### Phase 4: GitHub Repos — GCS plain + known upstream (44 packages)

These use plain GCS URLs (`gs://minimal-staging-archives/packagename-version.tar.gz`) without owner/repo in the path — pkgmgr's GCS regex can't auto-resolve these. Each mapping was resolved from build.ncl source comments (e.g. `# https://github.com/...`) and verified against the upstream project.

| Package | Owner | Repo |
|---------|-------|------|
| `acl` | acl | acl |
| `attr` | attr | attr |
| `boost` | boostorg | boost |
| `bzip2` | libarchive | bzip2 |
| `check` | libcheck | check |
| `curl` | curl | curl |
| `expat` | libexpat | libexpat |
| `file` | file | file |
| `flex` | westes | flex |
| `git` | git | git |
| `iana-etc` | Mic92 | iana-etc |
| `jq` | jqlang | jq |
| `lcms2` | mm2 | Little-CMS |
| `less` | gwsw | less |
| `libcap` | libcap | libcap |
| `libffi` | libffi | libffi |
| `libjpeg-turbo` | libjpeg-turbo | libjpeg-turbo |
| `libpng` | pnggroup | libpng |
| `libpsl` | rockdaboot | libpsl |
| `libxcrypt` | besser82 | libxcrypt |
| `linux_headers` | torvalds | linux |
| `llvm` | llvm | llvm-project |
| `lz4` | lz4 | lz4 |
| `node` | nodejs | node |
| `opencv` | opencv | opencv |
| `openssh` | openssh | openssh-portable |
| `pciutils` | pciutils | pciutils |
| `pcre2` | PCRE2Project | pcre2 |
| `perl` | Perl | perl5 |
| `pkgconf` | pkgconf | pkgconf |
| `postgres` | postgres | postgres |
| `python` | python | cpython |
| `rust` | rust-lang | rust |
| `setuptools` | pypa | setuptools |
| `shadow` | shadow-maint | shadow |
| `sqlite` | sqlite | sqlite |
| `strace` | strace | strace |
| `tcl` | tcltk | tcl |
| `util-linux` | util-linux | util-linux |
| `uv` | astral-sh | uv |
| `vim` | vim | vim |
| `xz` | tukaani-project | xz |
| `zlib` | madler | zlib |
| `zstd` | facebook | zstd |

### Phase 5: GitHub Repos — alternate download sources (12 packages)

These download from PyPI, npm, go.dev, etc. — outside pkgmgr's URL regex coverage. Their authoritative source repo is on GitHub, mapped from canonical upstream project pages.

| Package | Owner | Repo | Download source |
|---------|-------|------|----------------|
| `build` | pypa | build | PyPI |
| `flit-core` | pypa | flit | PyPI |
| `ffmpeg` | FFmpeg | FFmpeg | ffmpeg.org |
| `go` | golang | go | go.dev |
| `gradle` | gradle | gradle | gradle.org |
| `meson-python` | mesonbuild | meson-python | PyPI |
| `nginx` | nginx | nginx | nginx.org |
| `numpy` | numpy | numpy | PyPI |
| `packaging` | pypa | packaging | PyPI |
| `pip` | pypa | pip | PyPI |
| `pnpm` | pnpm | pnpm | npm registry |
| `pyproject-hooks` | pypa | pyproject-hooks | PyPI |
| `pyproject-metadata` | pypa | pyproject-metadata | PyPI |
| `zig` | ziglang | zig | ziglang.org |

---

## Skipped Packages

### Meta / No-source packages (5) — no provenance applicable

| Package | Reason |
|---------|--------|
| `base` | Meta-package, bundles other packages |
| `minimal-sshd` | Meta-package |
| `resolver-quad8` | Configuration-only |
| `toolchain` | Meta-package |
| `toolchain-gnullvm` | Meta-package |

### Other / non-GitHub non-GNU (7) — no matching category

| Package | Source | Notes |
|---------|--------|-------|
| `android-sdk` | dl.google.com | Google proprietary distribution |
| `ca-certificates` | GCS aggregate bundle | No single upstream repo |
| `claude-code` | GCS Anthropic binary | Proprietary distribution |
| `expect` | SourceForge | No active GitHub repo |
| `maven` | archive.apache.org | Apache project |
| `minimal` | GCS internal | Bootstrap package |
| `diffoscope` | salsa.debian.org | Debian GitLab |

### Borderline — primary home is GitLab/freedesktop/kernel.org (12) — defer

These projects' canonical repos are not on GitHub. A future `'GitlabRepo` or `'FreedesktopProject` category may be appropriate.

| Package | Primary home |
|---------|-------------|
| `cairo` | gitlab.freedesktop.org/cairo/cairo |
| `elfutils` | sourceware.org/elfutils |
| `fontconfig` | gitlab.freedesktop.org/fontconfig/fontconfig |
| `freetype` | gitlab.freedesktop.org/freetype/freetype |
| `graphviz` | gitlab.com/graphviz/graphviz |
| `iproute2` | kernel.org |
| `libcap` | kernel.org |
| `libpipeline` | gitlab.com/man-db/libpipeline |
| `man-db` | gitlab.com/man-db/man-db |
| `pixman` | gitlab.freedesktop.org/pixman/pixman |
| `procps-ng` | gitlab.com/procps-ng/procps |

---

## Implementation Approach

### Owner/Repo Resolution via pkgmgr

The `owner/repo` for each package is resolved using the same regex-based URL parsing that `pkgmgr` (`../pkgmgr`) uses internally. This ensures consistency with the existing package management tooling.

**GCS URL extraction** (`pkgmgr/internal/package_manager/manager.go`):
```go
gcsURLRe := regexp.MustCompile(`url\s*=\s*"(gs://[^/]+/([^/"\s]+/[^/"\s]+)/[^"]*%\{version\}[^"]*)"`)
```
Matches GCS URLs in the format `gs://bucket/owner/repo/...` and extracts the `owner/repo` path segment directly. This covers Phase 2 packages (53 packages with `gs://minimal-staging-archives/{owner}/{repo}/...` URLs).

**GitHub URL extraction** (fallback):
```go
urlFieldRe := regexp.MustCompile(`url\s*=\s*"(https://github\.com/([^/]+/[^/]+)/archive/refs/tags/[^"]+)"`)
```
Extracts `owner/repo` from direct `github.com` download URLs. This covers Phase 3 packages.

**Packages not matched by pkgmgr regexes** (Phases 4 & 5):
- **GCS plain URLs** (`gs://minimal-staging-archives/packagename-version.tar.gz`) don't contain `owner/repo` in the path, so pkgmgr can't auto-resolve them. These were mapped to their known GitHub upstreams by cross-referencing the GCS archive comments in build.ncl (many contain `# https://github.com/...` hints) and verifying against the upstream project.
- **Alternate source URLs** (PyPI, npm, go.dev, etc.) also fall outside pkgmgr's regex patterns. These were mapped to their canonical GitHub repos.

### Edit Pattern

Most packages use one of two `attrs` styles that need updating:

**Style A — shorthand (most common):**
```nickel
# Before:
  attrs.upstream_version = version,

# After:
  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "owner",
      repo = "repo",
    },
  } | Attrs,
```

**Style B — already a block (some packages):**
```nickel
# Before:
  attrs = {
    upstream_version = version,
    repology_project = "redis",
  } | Attrs,

# After:
  attrs = {
    upstream_version = version,
    repology_project = "redis",
    source_provenance = {
      category = 'GithubRepo,
      owner = "redis",
      repo = "redis",
    },
  } | Attrs,
```

**Style C — GNU projects:**
```nickel
  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GnuProject,
      name = "bash",
    },
  } | Attrs,
```

### Execution Plan

1. **Phase 1 (GNU)**: 35 packages — well-known GNU project names
2. **Phase 2 (GCS owner/repo)**: 53 packages — owner/repo extracted via pkgmgr GCS URL regex
3. **Phase 3 (Direct GitHub)**: 19 packages — owner/repo extracted via pkgmgr GitHub URL regex
4. **Phase 4 (GCS plain)**: 44 packages — owner/repo resolved from build.ncl source comments and upstream verification (not auto-resolvable by pkgmgr)
5. **Phase 5 (Alternate sources)**: 12 packages — owner/repo resolved from canonical upstream repos (PyPI/npm/etc. sources not covered by pkgmgr regexes)

Each phase can be committed separately for clean review.

### Validation

After each phase:
- Verify NCL syntax is valid (no trailing comma issues, correct `| Attrs` contract)
- Cross-check owner/repo against pkgmgr's URL resolution for GCS/GitHub URL packages
- For plain GCS and alternate-source packages, verify owner/repo against the upstream project
- Confirm the `source_provenance` field placement is consistent with existing examples (cmake, glibc, tailscale)

### Risk Assessment

- **Low risk**: This is additive metadata only — no build behavior changes
- **Schema validation**: The `attr_classes.ncl` contract validates category + required fields at eval time
- **No build impact**: `source_provenance` is consumed for metadata/SBOM only, not build execution
- **pkgmgr consistency**: Phases 2 & 3 use the same resolution logic as pkgmgr, ensuring the provenance data matches what the tooling would derive

---

## Summary

| Phase | Category | Count | Resolution method |
|-------|----------|-------|-------------------|
| 1 | GnuProject | 35 | Known GNU project names |
| 2 | GithubRepo (GCS owner/repo) | 53 | pkgmgr GCS URL regex |
| 3 | GithubRepo (direct GitHub) | 19 | pkgmgr GitHub URL regex |
| 4 | GithubRepo (GCS plain) | 44 | build.ncl source comments + upstream verification |
| 5 | GithubRepo (alternate sources) | 12 | Canonical upstream repo mapping |
| — | Skipped (meta/other/borderline) | 24 | N/A |
| **Total** | | **163 new + 3 existing** | |
