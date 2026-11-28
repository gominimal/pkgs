# Sourced by gcc-runtime/build.sh and gcc-runtime-fortran/build.sh. The two
# copies must stay byte-identical (.github/scripts/gcc_runtime_guard.py).
#
# Where to copy from. gcc's build stages its shared runtime libraries a second
# time under /usr/lib/gcc-runtime-stage, a path no other object ships, and this
# copies from there rather than /usr/lib. Where two layers of a build root ship
# one path, the first wins by spec-hash order, so a second gcc in this root
# would silently supply /usr/lib's files. On arm64 the gcc 16 canary
# (pkgs#1340) shipped gen-13 gcc 15's libstdc++.so.6 and libgcc_s.so.1 that
# way, through a bootstrap gcc that gmp's gcc-runtime edge pulled in.
# gcc_runtime_guard rule 4 now keeps gcc-runtime out of gcc's build graph, so
# that path cannot form; the stage keeps a regression there from shipping the
# wrong libraries without an error.
#
# No stage means the gcc build dep is itself gcc's bootstrap breaker: minimal's
# planner seed-builds a dependent of an unbuilt cycle member against that
# member's replace_on_cycle. Such an output is never published and is rebuilt
# against the real gcc. Then /usr/lib is all bootstrap gcc, and
# one_real_file below still fails the build if two gccs collided there.

src=/usr/lib/gcc-runtime-stage
dst="$OUTPUT_DIR/usr/lib"
mkdir -p "$dst"
if [ -d "$src" ]; then
  echo "copying gcc's staged runtime libraries from $src"
else
  echo "no $src: the gcc build dep is the bootstrap breaker; copying /usr/lib"
  src=/usr/lib
fi

# copy <glob>: copy every match (files and symlinks, as they are) and fail when
# gcc has none, so a library gcc stops shipping is an error, not an empty output.
copy() {
  found=0
  for f in "$src"/$1; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    case "$f" in *.py) continue ;; esac # libstdc++.so.6.*-gdb.py: debugger helper
    cp -P "$f" "$dst/"
    found=1
  done
  [ "$found" -eq 1 ] || { echo "ERROR: gcc build dep has no $src/$1" >&2; exit 1; }
}

# one_real_file <glob> <soname>: exactly one real file matches <glob> in the
# output and <soname> is a symlink to it. Two real files mean two gccs' copies
# were mixed; a regular file at <soname> means one gcc's file shadowed the
# other's link (both happened on arm64 in pkgs#1340 run 7e4acbc4).
one_real_file() {
  n=0
  real=
  for f in "$dst"/$1; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      n=$((n + 1))
      real=${f##*/}
    fi
  done
  [ "$n" -eq 1 ] || { echo "ERROR: expected one real $1 in $dst, found $n" >&2; ls -l "$dst" >&2; exit 1; }
  [ -L "$dst/$2" ] || { echo "ERROR: $dst/$2 is not a symlink" >&2; ls -l "$dst" >&2; exit 1; }
  [ "$(readlink "$dst/$2")" = "$real" ] || { echo "ERROR: $2 -> $(readlink "$dst/$2"), expected $real" >&2; exit 1; }
}
