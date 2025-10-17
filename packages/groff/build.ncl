let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let bash = import "../bash/build.ncl" in
let tar = import "../tar/build.ncl" in
let sed = import "../sed/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let m4 = import "../m4/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let perl = import "../perl/build.ncl" in
{
  name = "groff",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/groff-1.23.0.tar.gz",
      sha256 = "6b9757f592b7518b4902eb6af7e54570bdccba37a871fddb2d30ae3863511c13"
    } | Source,
    base,
    toolchain,
    coreutils,
    binutils,
    bash,
    tar,
    sed,
    make,
    gcc,
    autoconf,
    automake,
    m4,
    perl,
  ],
  runtime_deps = [
  ],

  cmd = "./build.sh",
  outputs = {
    bin = { glob = "usr/bin/*" } | OutputBin,
    man = { glob = "usr/share/man/**/*" } | OutputData,
    info = { glob = "usr/share/info/*" } | OutputData,
    data = { glob = "usr/share/groff/**" } | OutputData,
  },
} | BuildSpec
