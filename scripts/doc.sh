# Tangle, export each .org to LaTeX with minted, then latexmk it in place.
tangle-org

mapfile -t orgs < <(
  find . \( -name .git -o -name .direnv -o -name _build -o -name .lake -o -name latex -o -name output \) -prune \
    -o -type f -name '*.org' -print | sort
)
if (( ${#orgs[@]} == 0 )); then
  echo "doc-org: no .org files under $PWD" >&2
  exit 0
fi

fail=0
for f in "${orgs[@]}"; do
  dir=$(dirname "$f")
  base=$(basename "$f" .org)
  echo "-- export $f"
  if ! emacs --batch "$f" -l "$OX_SETUP" -f org-latex-export-to-latex; then
    fail=1
    continue
  fi
  echo "-- latexmk $dir/$base.tex"
  if ! (cd "$dir" && TEXINPUTS=".:latex:${TEXINPUTS:-}" latexmk -lualatex -shell-escape -interaction=nonstopmode "$base.tex"); then
    fail=1
  fi
done
if (( fail )); then
  echo "FAIL  literate docs"
  exit 1
fi
echo "PASS  literate docs"
