#!/usr/bin/env bash
# Counts what myst-theme exposes to a stylesheet, and how much of it theme.css brands. The numbers
# in docs/theming-surface.md come from here; rerun after a theme bump to see what moved.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-${MYST_THEME_SRC:-}}"

if [ -z "$SRC" ] || [ ! -d "$SRC/packages" ]; then
  echo "usage: $(basename "$0") <path to a myst-theme checkout>" >&2
  echo "   or: MYST_THEME_SRC=<path> $(basename "$0")" >&2
  echo "get one with: git clone https://github.com/jupyter-book/myst-theme" >&2
  exit 2
fi

emitted=$(rg -o 'myst-[a-z0-9-]+' "$SRC/packages" "$SRC/themes" \
  --glob '*.tsx' --glob '*.ts' --no-filename | sort -u)
ours=$(rg -o 'myst-[a-z0-9-]+' "$ROOT/theme.css" | sort -u)

printf 'custom properties  %s\n' "$(rg -o -- '--myst-color-[a-z-]+' "$SRC/styles/theme-colors.css" | sort -u | wc -l)"
printf 'classes emitted    %s\n' "$(wc -l <<<"$emitted")"
printf 'classes branded    %s\n\n' "$(wc -l <<<"$ours")"

printf '%-16s %8s %8s\n' FAMILY EMITTED BRANDED
sed -E 's/myst-([a-z0-9]+).*/\1/' <<<"$emitted" | sort -u | while read -r f; do
  e=$(grep -c "^myst-$f" <<<"$emitted" || true)
  o=$(grep -c "^myst-$f" <<<"$ours" || true)
  # The test is last in the loop body, so its status becomes the loop's. Under set -e a family
  # below the cutoff would end the script here, with every section after this one unprinted.
  if [ "$e" -ge 4 ]; then printf '%-16s %8s %8s\n' "$f" "$e" "${o:-0}"; fi
done

# A class we style that the theme never emits is either renamed upstream or a typo here. Two kinds
# of expected absence are filtered: the eight admonition kinds, built by interpolation and so never
# literals, and the --myst-color-* names, which are custom properties rather than classes.
printf '\nstyled here, absent from the theme source (empty is the healthy answer):\n'
comm -23 <(echo "$ours") <(echo "$emitted") |
  grep -v -e '^myst-admonition-' -e '^myst-color-' | sed 's/^/  /' || true

# The variables only work once the bundled theme carries them, which its version string does not say
printf '\n--myst-color- in the built theme (0 means the variables are inert):\n'
for css in "$ROOT"/*/_build/templates/site/myst/*/*/public/build/_assets/app-*.css; do
  [ -f "$css" ] || continue
  printf '  %-30s %s\n' "$(basename "$(dirname "$(dirname "$(dirname "$(dirname "$css")")")")")" \
    "$(rg -c -- '--myst-color-' "$css" || echo 0)"
done
