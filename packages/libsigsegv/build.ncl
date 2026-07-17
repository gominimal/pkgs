# libsigsegv — GNU library for page-fault / stack-overflow handling in user
# mode. A Maude (rewriting engine) build prerequisite; see pkgmgr-rs#528.
let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.14" in
{
  name = "libsigsegv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libsigsegv-%{version}.tar.gz",
      sha256 = "cdac3941803364cf81a908499beb79c200ead60b6b5b40cad124fd1e06caa295",
      extract = true,
      strip_prefix = "libsigsegv-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "libsigsegv",
      },
    } | Attrs,
} | BuildSpec
