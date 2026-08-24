#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export TZ=UTC
export LC_ALL=C
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu17 -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu++17 -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# tree-sitter 0.26 renamed ts_language_version() -> ts_language_abi_version()
# and removed the old declaration from api.h. Emacs 30.2's treesit.c still calls
# the old name, so the build dies at src/treesit.c:749 with
#   error: implicit declaration of function 'ts_language_version';
#          did you mean 'ts_language_abi_version'?
# Rename at the call sites. Word-anchored so it can't touch an already-correct
# ts_language_abi_version, which makes it a no-op if Emacs upstream fixes this
# in a later version bump.
sed -i 's/\bts_language_version\b/ts_language_abi_version/g' src/treesit.c

# tree-sitter >= 0.26 also rejects query predicates without a ?/! suffix,
# but Emacs 30.2 emits "#match"/"#equal"/"#pred" and only accepts those
# names back, so every :match font-lock rule (go-ts-mode, python-ts-mode,
# typescript-ts-mode, ...) dies with treesit-query-error and the buffer
# loses highlighting. Backport of the upstream fix (master b0143530,
# bug#79687); see the patch header. Drop once an Emacs release has it.
patch -Np1 -i treesit-predicates-0.26.patch

# Build LD_PRELOAD shim that makes getrandom() and /dev/urandom reads
# deterministic, fixing Emacs hash table seeding and thus .elc/.pdmp output.
gcc -shared -fPIC -O2 -ldl -o fixrand.so fixrand.c

./configure --prefix=/usr \
  --without-all \
  --without-x \
  --without-ns \
  --with-gnutls \
  --with-xml2 \
  --with-zlib \
  --with-tree-sitter \
  --with-modules \
  --with-threads \
  --with-file-notification=inotify \
  --without-compress-install \
  --disable-build-details \
  MAKEINFO=true

LD_PRELOAD=$(pwd)/fixrand.so make MAKEINFO=true -j$(nproc)
LD_PRELOAD=$(pwd)/fixrand.so make MAKEINFO=true DESTDIR=$OUTPUT_DIR install

# Replace the emacs symlink with a wrapper that picks user-emacs-directory:
# the personal config dir $XDG_CONFIG_HOME/emacs (Emacs's own XDG location,
# and where a loadout's patched init.el lands) when it holds an init file,
# otherwise an ephemeral /tmp path so no writable ~/.emacs.d is needed.
# Passing --init-directory explicitly in both cases keeps the choice
# independent of Emacs's own ~/.emacs.d-vs-XDG fallback rules.
rm "$OUTPUT_DIR/usr/bin/emacs"
cat > "$OUTPUT_DIR/usr/bin/emacs" <<'WRAPPER'
#!/bin/sh
# .elc variants count as personal config: startup--load-user-init-file
# strips the .el extension before `load', so Emacs picks up init.elc /
# early-init.elc even without sources.
dir="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"
if [ ! -f "$dir/init.el" ] && [ ! -f "$dir/init.elc" ] \
   && [ ! -f "$dir/early-init.el" ] && [ ! -f "$dir/early-init.elc" ]; then
  # Ephemeral fallback. Per-user under XDG_CACHE_HOME rather than a
  # shared, predictable /tmp path that another user could pre-seed with
  # an init.el; a throwaway dir if the cache is missing or not writable
  # (mkdir -p succeeds on an existing read-only dir, hence the -w test).
  dir="${XDG_CACHE_HOME:-$HOME/.cache}/emacs.d"
  mkdir -p "$dir" 2>/dev/null && [ -w "$dir" ] || dir="$(mktemp -d /tmp/emacs.d.XXXXXX)"
fi
exec emacs-30.2 --init-directory "$dir" "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/emacs"

# Install site-start.el: sets up load-path for site-lisp subdirectories and
# discovers/loads all minimal-init-*.el config fragments from emacs-config-*
# packages -- unless the user has an init file of their own, which wins.
cat > "$OUTPUT_DIR/usr/share/emacs/site-lisp/site-start.el" <<'SITESTART'
;;; site-start.el --- Minimal composable config loader -*- lexical-binding: t; -*-

;; Add site-lisp subdirectories (and their lisp/extensions children) to load-path.
;; This ensures elisp packages from any emacs-config-* or emacs-site-lisp
;; package are loadable.
(let ((site-lisp-dir (file-name-directory (or load-file-name buffer-file-name))))
  (dolist (dir (directory-files site-lisp-dir t "\\`[^.]"))
    (when (file-directory-p dir)
      (add-to-list 'load-path dir)
      (dolist (sub '("lisp" "extensions"))
        (let ((subdir (expand-file-name sub dir)))
          (when (file-directory-p subdir)
            (add-to-list 'load-path subdir))))))
  ;; Load all minimal-init-*.el config fragments in sorted order -- unless
  ;; user-emacs-directory (chosen by the /usr/bin/emacs wrapper, which
  ;; prefers $XDG_CONFIG_HOME/emacs when it holds an init file) already
  ;; carries a personal init file: that takes precedence over packaged
  ;; fragments. A personal init that wants a fragment anyway can load it
  ;; explicitly, e.g. (load "minimal-init-dev1").
  (unless (or (file-exists-p (expand-file-name "init.el" user-emacs-directory))
              (file-exists-p (expand-file-name "init.elc" user-emacs-directory)))
    (dolist (init-file (sort (file-expand-wildcards
                              (expand-file-name "minimal-init-*.el" site-lisp-dir))
                             #'string<))
      (load init-file t t))))

;;; site-start.el ends here
SITESTART
