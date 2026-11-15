# Sourced by gcc-runtime/build.sh and gcc-runtime-fortran/build.sh. The two
# copies must stay byte-identical (.github/scripts/gcc_runtime_guard.py).
#
# Where to copy from. gcc's build stages its shared runtime libraries a second
# time under /usr/lib/gcc-runtime-stage, a path no other object ships. Plain
# /usr/lib is not safe: this build root also holds gcc-runtime's cycle breaker
# (a bootstrap gcc, via gcc -> gmp -> gcc-runtime), and where two layers ship
# one path the first wins by spec-hash order. On arm64 that shipped the gen-13
# gcc 15 libstdc++.so.6 and libgcc_s.so.1 in the gcc 16 canary (pkgs#1340).
#
# No stage means the gcc build dep is itself the bootstrap breaker: the first
# pass of the gcc <-> gcc-runtime cycle, whose output only feeds builds inside
# the cycle before both are rebuilt. Then /usr/lib is all bootstrap gcc, and
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
