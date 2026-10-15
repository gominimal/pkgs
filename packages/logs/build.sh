#!/bin/sh
# dbuenzli/logs, the core library only. Upstream builds with topkg on top of
# ocamlbuild, neither of which is packaged; the core is one dependency-free
# module, so compile it directly. The optional sub-libraries (logs.fmt,
# logs.cli, logs.lwt, logs.threaded, logs.top, logs.browser) are not built;
# nothing in pkgs uses them (charon-ml needs only `logs`).
set -eu
tar -xof "logs-${MINIMAL_ARG_VERSION}.tbz"
cd "logs-${MINIMAL_ARG_VERSION}"
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"

cd src
ocamlfind ocamlc -bin-annot -c logs.mli
ocamlfind ocamlc -bin-annot -c logs.ml
ocamlfind ocamlc -a -o logs.cma logs.cmo
ocamlfind ocamlopt -c logs.ml
ocamlfind ocamlopt -a -o logs.cmxa logs.cmx
ocamlfind ocamlopt -shared -linkall -o logs.cmxs logs.cmxa

# Upstream's META, top block only: the sub-packages describe archives that
# were not built.
sed '/^package /,$d' ../pkg/META > META
grep -q 'archive(native) = "logs.cmxa"' META

mkdir -p "$OUTPUT_DIR/usr/lib/ocaml"
ocamlfind install -destdir "$OUTPUT_DIR/usr/lib/ocaml" logs META \
  logs.mli logs.cmi logs.cmti logs.cmx logs.cma logs.cmxa logs.a logs.cmxs
