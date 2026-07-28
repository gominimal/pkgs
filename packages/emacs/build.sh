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

# Replace the emacs symlink with a wrapper that redirects user-emacs-directory
# to an ephemeral /tmp path, avoiding the need for a writable ~/.emacs.d
rm "$OUTPUT_DIR/usr/bin/emacs"
cat > "$OUTPUT_DIR/usr/bin/emacs" <<'WRAPPER'
#!/bin/sh
dir="/tmp/emacs.d"
mkdir -p "$dir"
exec emacs-30.2 --init-directory "$dir" "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/emacs"

# Install site-start.el: sets up load-path for site-lisp subdirectories and
# discovers/loads all minimal-init-*.el config fragments from emacs-config-* packages.
cat > "$OUTPUT_DIR/usr/share/emacs/site-lisp/site-start.el" <<'SITESTART'
;;; site-start.el --- Minimal composable config loader -*- lexical-binding: t; -*-

;; Add site-lisp subdirectories (and their lisp/extensions children) to load-path.
;; This ensures elisp packages from any emacs-config-* package are loadable.
(let ((site-lisp-dir (file-name-directory (or load-file-name buffer-file-name))))
  (dolist (dir (directory-files site-lisp-dir t "\\`[^.]"))
    (when (file-directory-p dir)
      (add-to-list 'load-path dir)
      (dolist (sub '("lisp" "extensions"))
        (let ((subdir (expand-file-name sub dir)))
          (when (file-directory-p subdir)
            (add-to-list 'load-path subdir))))))
  ;; Load all minimal-init-*.el config fragments in sorted order.
  (dolist (init-file (sort (file-expand-wildcards
                            (expand-file-name "minimal-init-*.el" site-lisp-dir))
                           #'string<))
    (load init-file t t)))

;;; site-start.el ends here
SITESTART
