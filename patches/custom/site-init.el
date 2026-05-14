(add-hook 'before-init-hook
  (lambda ()
    (setq treesit-extra-load-path
          (list (expand-file-name "tree-sitter" invocation-directory)))))
