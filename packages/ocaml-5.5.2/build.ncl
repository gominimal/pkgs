let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
# ocaml-5.5.2: the boot compiler for `ocaml`, from gen-11 of gominimal/bootstrap: the top of a
# source-only ladder with no OCaml binary as input, camlboot (OCaml 4.07's compiler interpreted
# under Guile) -> ocaml-4.07.1 -> 4.08.1 -> 4.09.0 -> 4.10.2 -> 4.11.2 -> 4.12.1 -> 4.13.1 -> 4.14.3
# -> 5.0.0 -> 5.1.1 -> 5.2.1 -> 5.3.0 -> 5.4.0 -> 5.5.2, every tarball's shipped boot/ocamlc
# deleted, each rung built by the previous one on the hex0-rooted toolchain and this one
# reproduced byte for byte on two independent machines per arch before publishing
# (generations/gen-11/manifest.json). Installs the whole compiler at /usr/lib/ocaml-5.5.2;
# nothing lands on /usr/bin.
let version = "5.5.2" in
{
  name = "ocaml-5.5.2",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-11/sha256/7f801d4ca5830577cfccf7f9ffa1decd2ca09f97387d4a348945fa9dbe5acfe7/ocaml-5.5.2-x86_64.tar.zst",
          sha256 = "7f801d4ca5830577cfccf7f9ffa1decd2ca09f97387d4a348945fa9dbe5acfe7",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-11/sha256/324269d0c69d61237d8bfa7ba00cb93d31eed65345322005ec9bf82e9f2b3da9/ocaml-5.5.2-aarch64.tar.zst",
          sha256 = "324269d0c69d61237d8bfa7ba00cb93d31eed65345322005ec9bf82e9f2b3da9",
          extract = true,
        } | Source,
    } target,
  ],
  runtime_deps = [glibc, toolchain], # ocamlopt links through the gcc driver
  outputs = {
    prefix = { glob = "usr/lib/ocaml-5.5.2/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/ocaml-5.5.2/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-only WITH OCaml-LGPL-linking-exception",
      source_provenance = {
        category = 'Website,
        homepage = "https://ocaml.org/",
        downloads_page = "https://caml.inria.fr/pub/distrib/ocaml-5.5/",
      },
    } | Attrs,
} | BuildSpec
