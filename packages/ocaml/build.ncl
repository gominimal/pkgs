let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

# ── BEDROCK TRIO (issue #48) — off the self-hosting clique, onto the seed-rooted anchor ──────
# `../toolchain` is a meta-package over ../gcc + ../binutils + ../glibc + ../linux_headers, and
# packages/gcc/build.ncl IMPORTS ITSELF (line 20) — it is a self-hosting FIXED POINT with no
# acyclic genesis to hex0.  Building OCaml on it means OCaml's root is "the gcc we already had".
# The bedrock trio instead roots this package at B5, whose chain is
#   hex0 -> hex1 -> mes -> tcc -> gcc-4.0.4 -> ... -> gcc-10.4.0 -> stage0-gcc-15.2.0 (R12)
#   -> gcc-15.2.0-glibc (B5)
# Precedent + harness shape copied from packages/mrustc (the C++ joint, issue #17).
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5: seed-rooted gcc/g++ 15.2.0
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # B5-matched as/ld/ar/ranlib/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: sysroot (headers+crt+libs+UAPI)

let version = "5.5.0" in
{
  name = "ocaml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml/ocaml/releases/download/5.5.0/ocaml-5.5.0.tar.gz
      url = "gs://minimal-staging-archives/ocaml-%{version}.tar.gz",
      sha256 = "c018052c8264a3791a8f54f84179e6bcc78ed82eb889bacc2773df445259aed3",
      extract = true,
      strip_prefix = "ocaml-%{version}",
    } | Source,
    base,
    gcc-bedrock,
    binutils-bedrock,
    glibc-bedrock,
    make,
  ],
  # OCaml self-bootstraps from the tarball's own boot/ocamlc bytecode image, so
  # NO `needs { internet }` — the entire build is offline. The only inputs are a
  # C compiler + make (now the seed-rooted bedrock trio, see above).
  #
  # runtime_deps: `ocamlopt` links every native binary by invoking the gcc
  # DRIVER (gcc -> cc1 -> collect2 -> ld), not ld directly — that driver lives
  # in gcc's `bins` + `libexec_bins`, NOT the `libgcc` subset (which is only
  # libgcc_s.so). So carry the whole trio, not `subsetOf gcc ["libgcc"]`.
  #
  # ⚠ WHY THE RUNTIME SET MUST MATCH THE BUILD SET, EXACTLY.
  # Unlike mrustc (which declares NO runtime_deps, per bedrock convention), OCaml PERSISTS its
  # toolchain configuration: ./configure records the C compiler and its flags into
  # Makefile.config, which is compiled into config.ml and baked into the installed ocamlopt.
  # ocamlopt then RE-INVOKES that exact command at runtime to link every native binary a user
  # builds. So the sysroot ocamlopt was configured against must still exist, at the same absolute
  # paths, in the consumer's rootfs. Shipping bedrock at build time but `toolchain` at runtime
  # would link user programs against a DIFFERENT glibc than ocaml's own libasmrun.a was compiled
  # for — an ABI mismatch that would surface as corrupt binaries, not a clean error.
  # This is also why build.sh must NOT use a $BUILDROOT wrapper script as $CC the way mrustc
  # does: that path is gone at runtime. It configures plain `gcc` + absolute sysroot flags.
  runtime_deps = [
    gcc-bedrock,
    binutils-bedrock,
    glibc-bedrock,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    # The stdlib tree: *.cma/.cmxa/.cmi/.cmx/.a plus stublibs *.so and the
    # `expunge`/`extract_crc` helper executables — hence allow_executable.
    stublibs = { glob = "usr/lib/ocaml/stublibs/*.so*" } | OutputLib,
    stdlib = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
    # The regenerated B4 libc.so linker script (build.sh FIXLIB). ocamlopt BAKES `-L` at this
    # path and re-reads it at runtime to link user programs, so it MUST ship with the package —
    # note it is deliberately outside usr/lib/ocaml/, so the stdlib glob does not cover it.
    bedrock_link = { glob = "usr/lib/ocaml-bedrock-link/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      # VERIFY -only vs -or-later against the tarball LICENSE (importer F1 guard).
      license_spdx = "LGPL-2.1-only WITH OCaml-LGPL-linking-exception",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml",
        repo = "ocaml",
      },
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/ocaml -version | grep -q '%{version}'"],
        ],
      } | Test,
    # The real proof the toolchain is whole: bytecode AND native compilation of
    # a trivial program, exercising ocamlc, ocamlopt, and the gcc driver
    # ocamlopt shells out to.
    compile_bytecode_and_native =
      {
        class = 'Standalone,
        # The bedrock trio, not `toolchain`: the ocamlopt leg of this test makes ocamlopt shell
        # out to the very gcc driver + sysroot it was configured against, so the test set has to
        # be the runtime set. With `toolchain` here the native leg would link against a different
        # glibc than ocaml's libasmrun.a was built for.
        test_deps = [base, gcc-bedrock, binutils-bedrock, glibc-bedrock, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = print_string \"ok\"' > t.ml && /usr/bin/ocamlc t.ml -o tb && ./tb | grep -q ok"],
          ["/bin/bash", "-c", "echo 'let () = print_string \"ok\"' > t.ml && /usr/bin/ocamlopt t.ml -o tn && ./tn | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
