#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu17 -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu++17"

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
  MAKEINFO=true

make MAKEINFO=true -j$(nproc)
make MAKEINFO=true DESTDIR=$OUTPUT_DIR install

# Replace the emacs symlink with a wrapper that redirects user-emacs-directory
# to an ephemeral /tmp path, avoiding the need for a writable ~/.emacs.d
rm "$OUTPUT_DIR/usr/bin/emacs"
cat > "$OUTPUT_DIR/usr/bin/emacs" <<'WRAPPER'
#!/bin/sh
dir="/tmp/emacs.d"
mkdir -p "$dir"
exec emacs-30.1 --init-directory "$dir" "$@"
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
