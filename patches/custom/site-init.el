;;; -*-lexical-binding:t-*-

(setq source-directory
      (concat "/home/emacs-dmg-build/build/emacs-" emacs-version))

(add-hook 'before-init-hook
  (lambda ()
    (setq treesit-extra-load-path
          (list (expand-file-name "tree-sitter" invocation-directory)))))
