let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let sed = import "../sed/build.ncl" in

let version = "0.10.0" in
{
  name = "logs",
  # dbuenzli/logs: logging infrastructure for OCaml. charon-ml needs it from
  # 0.1.281 on (`(libraries ... logs ...)`). Core library only; see build.sh.
  # Canonical release tarball from erratique.ch, mirrored to gs://.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/logs-%{version}.tbz",
      sha256 = "760ec291c128d75b74826091337764f925b5ca414b02e2d336a0b37bf30df4ea",
      # minimal's extractor doesn't know `.tbz`; build.sh unpacks it (as csexp).
      extract = false,
    } | Source,
    base,
    ocaml,
    ocamlfind,
    toolchain,
    sed,
    grep,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    logs = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      license_spdx = "ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dbuenzli",
        repo = "logs",
      },
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query logs | grep -q /usr/lib/ocaml"],
          # Link a program against it and check a message actually goes through.
          ["/bin/bash", "-c", "cd $(mktemp -d) && printf 'let () = Logs.set_reporter (Logs.format_reporter ()); Logs.set_level (Some Logs.Info); Logs.info (fun m -> m \"hello-from-logs\")\\n' > t.ml && OCAMLPATH=/usr/lib/ocaml ocamlfind ocamlopt -package logs -linkpkg t.ml -o t && ./t 2>&1 | grep -q hello-from-logs"],
        ],
      } | Test,
  },
} | BuildSpec
