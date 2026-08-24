#!/bin/sh
# AeneasVerif/aeneas (github, gs://-mirrored) — offline build. See build.ncl for
# why we patch out core_unix / progress / domainslib (none affect correctness).
set -eu
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"
export OCAMLPATH="/usr/lib/ocaml"
export CAML_LD_LIBRARY_PATH="/usr/lib/ocaml/stublibs"

# --- progress-bar stub (drops the `progress` opam lib; the bar is cosmetic) ---
cat > src/ProgressBar.ml <<'PROGRESSBAR_EOF'
(* minimal: `progress` is not packaged; the bar is cosmetic. Run the body with a
   no-op reporter, preserving the interface used across aeneas. *)
let with_reporter (_total : int) (_msg : string) (f : (int -> unit) -> 'a) : 'a =
  f (fun _ -> ())

let with_parallel_reporter (_total : int) (_msg : string)
    (f : (int -> unit) -> 'a) : 'a =
  f (fun _ -> ())
PROGRESSBAR_EOF

# --- parallel stub (drops the `domainslib` opam lib; output is deterministic) ---
cat > src/Parallel.ml <<'PARALLEL_EOF'
(* minimal: `domainslib` is not packaged. aeneas's output is deterministic, so we
   run every parallel combinator sequentially. Only Parallel.parallel_map is used
   externally; the rest are kept as aliases for interface stability. *)
let parallel_map (f : 'a -> 'b) (ls : 'a list) : 'b list = List.map f ls

let parallel_filter_map (f : 'a -> 'b option) (ls : 'a list) : 'b list =
  List.filter_map f ls

let parallel_map_pool = parallel_map
let parallel_filter_map_pool = parallel_filter_map
let parallel_map_chunks = parallel_map
let parallel_filter_map_chunks = parallel_filter_map
PARALLEL_EOF

# --- drop the last Jane Street uses (core / core_unix), stdlib replacements ---
# Translate.ml: Core_unix.mkdir_p -> stdlib recursive mkdir (Sys.mkdir).
sed -i 's|Core_unix\.mkdir_p dest_dir|(let rec mkdir_p d = if not (Sys.file_exists d) then (mkdir_p (Filename.dirname d); (try Sys.mkdir d 0o755 with Sys_error _ -> ())) in mkdir_p dest_dir)|' src/Translate.ml
# InterpPaths.ml: Core.Fn.compose f g  ==  fun x -> f (g x).
sed -i 's|Core\.Fn\.compose backward new_back|(fun x -> backward (new_back x))|' src/interp/InterpPaths.ml

# --- src/dune: drop core_unix / progress / domainslib from the aeneas library ---
sed -i '/^  core_unix$/d; /^  progress$/d; /^  domainslib$/d' src/dune

# aeneas's dune-project lives in src/ (the tarball has no root dune-project);
# build from wherever it is, falling back to the repo root if a future layout
# moves it there. The patches above all run from the repo root, so keep the cd here.
[ -f dune-project ] || cd src
dune build -p aeneas -j "$(nproc)" @install
dune install --prefix=/usr --libdir=/usr/lib/ocaml --destdir="$OUTPUT_DIR" aeneas
