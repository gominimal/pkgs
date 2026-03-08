let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let bash_bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk_bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
{
  name = "base-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
  ],
  runtime_deps = [
    bash_bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk_bootstrap,
    grep,
    gzip,
    sed,
    tar,
    xz,
  ],
  cmd = "build.sh",
  outputs = {
    hosts = { glob = "etc/hosts" } | OutputData,
  },
} | BuildSpec
