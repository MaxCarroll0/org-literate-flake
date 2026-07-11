; Batch org->LaTeX export settings: minted for src blocks, no evaluation on export.
(require 'ox-latex)
(setq org-latex-src-block-backend 'minted)
(add-to-list 'org-latex-packages-alist '("" "minted"))
(setq org-latex-minted-langs
      '((lean4 "lean4")
        (fstar "fstar")
        (emacs-lisp "common-lisp")
        (shell "bash")))
(setq org-confirm-babel-evaluate nil)
(setq org-export-with-broken-links 'mark)
