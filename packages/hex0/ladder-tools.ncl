# EXPERIMENT: the hex0 ladder's build tools, sealed.
#
# Each entry reuses a package's bedrock prebuilt (its `replace_on_cycle` tarball,
# sha-pinned, produced by the hex0 ladder via minimermetic's
# update-bedrock-roots.py) but gives it runtime_deps that point ONLY at other
# sealed prebuilts. The packages' own prebuilts declare runtime deps on the LIVE
# tree (coreutils (prebuilt) -> sealed-acl, sealed-glibc, sealed-gmp, libcap), which is right for
# their job as cycle breakers but re-links the ladder to every upstream change.
#
# runtime_deps below follow each amd64 tarball's DT_NEEDED (read 2026-10-06).
let { BuildSpec, OutputLib, Source, .. } = import "minimal.ncl" in
let sim = fun spec_name =>
  {
    name = spec_name,
    prebuilt = true,
    build_deps = [
      { url = "gs://SIMULATION-ONLY/%{spec_name}.tar.zst", sha256 = "0000000000000000000000000000000000000000000000000000000000000000", extract = true } | Source,
    ],
    outputs = { usr = { glob = "usr/**/*" } | OutputLib },
  } | BuildSpec
in


# (Parameters are not named `name` etc.: inside the record, `name = name` would
# refer to the field itself, an infinite recursion.)
let ladder = fun base spec_name rdeps =>
  {
    name = spec_name,
    prebuilt = true,
    build_deps = base.build_deps,
    outputs = base.outputs,
    runtime_deps = rdeps,
  } | BuildSpec
in

# Library prebuilts declare no runtime deps, so they are already sealed as-is.
let sealed-glibc = (import "../glibc/build.ncl").replace_on_cycle in
let sealed-acl = (import "../acl/build.ncl").replace_on_cycle in
let sealed-attr = (import "../attr/build.ncl").replace_on_cycle in
let sealed-gmp = (import "../gmp/build.ncl").replace_on_cycle in
let sealed-libcap = (import "../libcap/build.ncl").replace_on_cycle in
let sealed-pcre2 = (import "../pcre2/build.ncl").replace_on_cycle in
let sealed-mpfr = (import "../mpfr/build.ncl").replace_on_cycle in
let sealed-zstd = (import "../zstd/build.ncl").replace_on_cycle in
let sealed-zlib = (import "../zlib/build.ncl").replace_on_cycle in
let sealed-lz4 = (import "../lz4/build.ncl").replace_on_cycle in

let sealed-xz = ladder (import "../xz/build.ncl").replace_on_cycle "xz (ladder)" [sealed-glibc] in
let sealed-m4 = ladder (import "../m4/build.ncl").replace_on_cycle "m4 (ladder)" [sealed-glibc] in
{
  glibc = sealed-glibc,
  bash-bootstrap = ladder (import "../bash-bootstrap/build.ncl").replace_on_cycle "bash-bootstrap (ladder)" [sealed-glibc],
  coreutils = ladder (import "../coreutils/build.ncl").replace_on_cycle "coreutils (ladder)" [sealed-glibc, sealed-acl, sealed-attr, sealed-gmp, sealed-libcap],
  tar = ladder (import "../tar/build.ncl").replace_on_cycle "tar (ladder)" [sealed-glibc, sealed-acl],
  sed = ladder (import "../sed/build.ncl").replace_on_cycle "sed (ladder)" [sealed-glibc, sealed-acl, sealed-attr],
  grep = ladder (import "../grep/build.ncl").replace_on_cycle "grep (ladder)" [sealed-glibc, sealed-pcre2, sealed-zlib],
  gawk-bootstrap = ladder (import "../gawk-bootstrap/build.ncl").replace_on_cycle "gawk-bootstrap (ladder)" [sealed-glibc, sealed-mpfr, sealed-gmp],
  make = ladder (import "../make/build.ncl").replace_on_cycle "make (ladder)" [sealed-glibc],
  gzip = ladder (import "../gzip/build.ncl").replace_on_cycle "gzip (ladder)" [sealed-glibc],
  xz = sealed-xz,
  findutils = ladder (import "../findutils/build.ncl").replace_on_cycle "findutils (ladder)" [sealed-glibc],
  diffutils = ladder (import "../diffutils/build.ncl").replace_on_cycle "diffutils (ladder)" [sealed-glibc],
  bzip2 = ladder (import "../bzip2/build.ncl").replace_on_cycle "bzip2 (ladder)" [sealed-glibc],
  m4 = sealed-m4,
  bison = ladder (import "../bison/build.ncl").replace_on_cycle "bison (ladder)" [sealed-glibc, sealed-m4],
  file = ladder (import "../file/build.ncl").replace_on_cycle "file (ladder)" [sealed-glibc, sealed-zstd, sealed-xz, sealed-zlib, sealed-lz4],
  # SIMULATION ONLY (hash diff): stand-ins for tools with no sealed tarball yet.
  patch = sim "patch (ladder-sim)",
  gawk = sim "gawk (ladder-sim)",
  perl = sim "perl (ladder-sim)",
  python = sim "python (ladder-sim)",
}
