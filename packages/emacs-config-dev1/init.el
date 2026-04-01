;;; minimal-init-dev1.el --- Minimal developer Emacs configuration -*- lexical-binding: t; -*-

;;; Commentary:
;; Developer environment config fragment for the Minimal build system.
;; Loaded automatically by site-start.el via the minimal-init-* convention.
;; Provides a terminal-friendly developer environment with LSP support.

;;; Code:

;; ── General settings ──────────────────────────────────────────────────
(setq inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function 'ignore
      use-short-answers t
      make-backup-files nil
      auto-save-default nil
      create-lockfiles nil
      custom-file (expand-file-name "custom.el" user-emacs-directory))

;; Terminal-friendly UI
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(column-number-mode 1)
(global-display-line-numbers-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(savehist-mode 1)
(recentf-mode 1)

;; Theme
(load-theme 'modus-vivendi t)

;; Scrolling
(setq scroll-margin 3
      scroll-conservatively 101)

;; Indentation
(setq-default indent-tabs-mode nil
              tab-width 4)

;; ── Completion framework (vertico + orderless + marginalia + consult) ─
(when (require 'vertico nil t)
  (vertico-mode 1))

(when (require 'orderless nil t)
  (setq completion-styles '(orderless basic)
        completion-category-overrides '((file (styles partial-completion)))))

(when (require 'marginalia nil t)
  (marginalia-mode 1))

(when (require 'consult nil t)
  (global-set-key (kbd "C-x b") 'consult-buffer)
  (global-set-key (kbd "M-g g") 'consult-goto-line)
  (global-set-key (kbd "M-s l") 'consult-line)
  (global-set-key (kbd "M-s r") 'consult-ripgrep))

;; ── In-buffer completion (corfu) ──────────────────────────────────────
(when (require 'corfu nil t)
  (setq corfu-auto t
        corfu-auto-delay 0.2
        corfu-auto-prefix 2)
  (global-corfu-mode 1))

;; ── Which-key ─────────────────────────────────────────────────────────
(when (require 'which-key nil t)
  (which-key-mode 1))

;; ── Extra modes ───────────────────────────────────────────────────────
(require 'markdown-mode nil t)
(require 'yaml-mode nil t)
(require 'dockerfile-mode nil t)
(require 'nickel-mode nil t)
(require 'rust-mode nil t)

;; ── Magit ─────────────────────────────────────────────────────────────
;; Magit runs git at load time; wrap to avoid aborting default.el if
;; git is not installed.
(ignore-errors
  (when (require 'transient nil t)
    (when (require 'magit nil t)
      (global-set-key (kbd "C-x g") 'magit-status))))

;; ── Tree-sitter grammars and mode registrations ────────────────────────
(setq treesit-font-lock-level 4)

;; Point Emacs at the bundled grammar shared libraries.
(add-to-list 'treesit-extra-load-path "/usr/lib/emacs/tree-sitter")

;; Register tree-sitter modes for file types where grammars are available.
(dolist (entry '((rust       . ("\\.rs\\'"    . rust-ts-mode))
                 (go         . ("\\.go\\'"    . go-ts-mode))
                 (gomod      . ("go\\.mod\\'" . go-mod-ts-mode))
                 (typescript . ("\\.ts\\'"    . typescript-ts-mode))
                 (tsx        . ("\\.tsx\\'"   . tsx-ts-mode))
                 (python     . ("\\.py\\'"   . python-ts-mode))
                 (bash       . ("\\.sh\\'"   . bash-ts-mode))
                 (c          . ("\\.c\\'"    . c-ts-mode))
                 (cpp        . ("\\.[ch]pp\\'"  . c++-ts-mode))
                 (json       . ("\\.json\\'" . json-ts-mode))
                 (yaml       . ("\\.ya?ml\\'" . yaml-ts-mode))
                 (toml       . ("\\.toml\\'" . toml-ts-mode))))
  (when (treesit-language-available-p (car entry))
    (add-to-list 'auto-mode-alist (cdr entry))))

;; ── EditorConfig ──────────────────────────────────────────────────────
(when (fboundp 'editorconfig-mode)
  (editorconfig-mode 1))

;; ── Project detection ────────────────────────────────────────────
;; Tell project.el to recognise language-specific marker files as
;; project roots so eglot sends the correct workspace root to LSP
;; servers (instead of always defaulting to the git root).
(setq project-vc-extra-root-markers
      '("Cargo.toml" "go.mod" "package.json" "pyproject.toml"
        "setup.py" "compile_commands.json" "CMakeLists.txt"
        "meson.build"))

;; ── xref navigation (M-. / M-,) ─────────────────────────────────
;; Remove the etags backend so M-. never prompts "Visit TAGS table".
;; Eglot adds its own xref backend when active; this fallback gives a
;; clear message when no LSP server is running.
(remove-hook 'xref-backend-functions #'etags--xref-backend)

(defun minimal--xref-no-tags-backend () 'no-tags)
(cl-defmethod xref-backend-identifier-at-point ((_backend (eql 'no-tags)))
  (thing-at-point 'symbol t))
(cl-defmethod xref-backend-definitions ((_backend (eql 'no-tags)) identifier)
  (user-error "No LSP server running for `%s'" identifier))
(cl-defmethod xref-backend-references ((_backend (eql 'no-tags)) _identifier)
  (user-error "No LSP server running"))
(add-hook 'xref-backend-functions #'minimal--xref-no-tags-backend 100)

;; ── Eglot (LSP) ──────────────────────────────────────────────────────
;; Emacs 30 ships eglot with built-in entries for go, rust, python,
;; typescript, bash, c/c++ etc.  We only need to add nickel-mode.
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '(nickel-mode . ("nls"))))

;; Auto-start eglot for programming modes.  eglot-ensure is an
;; autoload that silently does nothing when no server is configured,
;; so it is safe to call on every prog-mode buffer.
(defun minimal--maybe-eglot ()
  "Start eglot unless this is an emacs-lisp buffer."
  (unless (derived-mode-p 'emacs-lisp-mode)
    (eglot-ensure)))

(add-hook 'prog-mode-hook #'minimal--maybe-eglot)

;; Format buffer via LSP on save when eglot is active.
(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (when (eglot-managed-p)
              (add-hook 'before-save-hook #'eglot-format-buffer nil t))))

;;; minimal-init-dev1.el ends here
