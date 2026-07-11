mapfile -t orgs < <(
  find . \( -name .git -o -name .direnv -o -name _build -o -name .lake -o -name latex -o -name output \) -prune \
    -o -type f -name '*.org' -print | sort
)
if (( ${#orgs[@]} == 0 )); then
  echo "tangle-org: no .org files under $PWD" >&2
  exit 0
fi
for f in "${orgs[@]}"; do
  echo "-- tangle $f"
  emacs --batch -l org --eval "(org-babel-tangle-file \"$f\")"
done
