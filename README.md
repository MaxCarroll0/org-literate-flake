# org-literate-flake

Literate programming machinery for languages **without** a native literate format (Lean 4, F*, ...): write a section as an org file whose src blocks tangle to real sources, then export to LaTeX/PDF with tikz-cd commutative diagrams and minted highlighting.

Languages with native literate formats keep them (Agda `.lagda.tex` via agda-flake, Isabelle document preparation via isabelle-flake, Coq coqdoc via coq-flake); this flake compiles the final PDFs.

## Use

```sh
# .envrc — follow HEAD (picks up updates automatically)
use flake "github:MaxCarroll0/org-literate-flake"

# or pin an exact commit for reproducibility, bumping deliberately
use flake "github:MaxCarroll0/org-literate-flake?rev=<sha>"
```

## Commands

```sh
nix run '...#tangle'   # org-babel-tangle every .org under $PWD
nix run '...#doc'      # tangle, org->LaTeX export (minted), latexmk -shell-escape per .org
```

## Org file conventions

- Tangle with `#+begin_src lean4 :tangle Categories.lean` (likewise `fstar`).
- Diagrams: `\begin{tikzcd} ... \end{tikzcd}` inside `#+begin_export latex` blocks; add `#+LATEX_HEADER: \usepackage{tikz-cd}`.
- Pull in Agda-generated LaTeX with `#+LATEX_HEADER: \usepackage{agda}` and `\input{latex/<Module/Path>.tex}` inside an export block; `latex/` is on `TEXINPUTS` during the build.

## Ground-up builds

Build hermetically from scratch with `nix build` (typecheck + document outputs as a derivation; no devshell involved). From the project root:

```sh
nix build --impure --expr \
  '(builtins.getFlake "github:MaxCarroll0/org-literate-flake").lib.${builtins.currentSystem}.mkBuild { src = ./.; }'
```

The result contains `doc.log`, a `status` file (`PASS`/`FAIL`), and the built PDFs.

## Formatting

`nix run .#fmt` (binary `fmt-org`) normalizes sources: trailing whitespace stripped, final newline ensured (these languages have no standard formatter, so formatting is deliberately conservative). Entering the devshell installs a git pre-commit hook that runs every `fmt-*` binary on the PATH over staged files and re-stages them, so stacked language flakes compose. `nix fmt` formats the flake's own nix code (nixfmt-rfc-style). A `.envrc` is included for using this repo directly.
