let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let patch = import "../patch/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.16.1" in
{
  name = "alsa-lib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # http://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2
      url = "gs://minimal-staging-archives/alsa-lib-%{version}.tar.bz2",
      sha256 = "f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e",
      extract = true,
      strip_prefix = "alsa-lib-%{version}",
    } | Source,
    # Security backport: CVE-2026-90781, one-byte stack overrun of the 64-byte
    # `buf` in __snd_ctl_ascii_elem_id_parse (src/control/ctlparse.c) when an
    # element-id string carries a name of 64+ characters. Upstream fixed it in
    # alsa-project/alsa-lib commit f84cd4ced7b3 (2026-08-30), after 1.2.16.1, the
    # latest release; Debian carries the same commit as 1.2.16.1-2. Verbatim
    # `git format-patch` of that commit, applied fail-closed in build.sh.
    { file = "CVE-2026-90781.patch" } | Local,
    # f84cd4ce "follows" upstream 1e27d63ef6d1 (2026-06-02), which fixes the
    # same one-byte overrun on the numid= branch of the same function and is
    # also not in 1.2.16.1. f84cd4ce alone leaves that site open, so both are
    # carried. Verbatim `git format-patch` of 1e27d63e.
    { file = "CVE-2026-90781-numid.patch" } | Local,
    base,
    make,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    aserver = { glob = "usr/bin/aserver" } | OutputBin,

    libasound = { glob = "usr/lib/libasound*.so*" } | OutputLib,
    libatopology = { glob = "usr/lib/libatopology*.so*" } | OutputLib,

    alsa_data = { glob = "usr/share/alsa/**" } | OutputData,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-only",
      repology_project = "alsa-lib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "alsa-project",
        repo = "alsa-lib",
      },
    } | Attrs,
} | BuildSpec
