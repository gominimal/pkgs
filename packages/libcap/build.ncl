let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash = import "../bash/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.77" in
{
  name = "libcap",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libcap-%{version}.tar.gz",
      sha256 = "5e339f5ab434bf5b7979f65437ca24942ddcd6e6a3e57347370cd791bc0ea51c",
      extract = true,
      strip_prefix = "libcap-%{version}",
    } | Source,
    bash,
    diffutils,
    grep,
    make,
    sed,
    linux_headers,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libcap",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libcap",
        repo = "libcap",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "libcap (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/libcap/1752dece484de73c426c2af4c37c660bd54ae2b5717d2406cbad6c645a2f667c.tar.zst",
              sha256 = "c8745d5b3f2cde821d48a8526f339dc39eb7915b82e47c86050219aba71941f3",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/libcap/arm64-linux-gnu/libcap_2.73_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "22041525efd9b1e1173f249b4abd279a41aa834b7314f430d448e83980260098",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
