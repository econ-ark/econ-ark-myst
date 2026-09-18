#!/usr/bin/env bash
# The one place this repository names a font release. CI, the Pages deploy and a contributor all
# run this, so the PDF and the site are set from the same files and nothing drifts between them.
#
#   scripts/fonts.sh install    put the faces where Typst will find them, for building the PDF
#   scripts/fonts.sh webfonts   write fonts/, the Latin subsets theme.css serves to a browser
#
# Another release renders the same words to different line breaks, which is why the tags are here
# rather than in each caller.

set -euo pipefail

FIRA_TAG=4.202
FIRAMATH_TAG=v0.3.4
# Must match the temml version package.json pins, which check-examples.sh asserts
TEMML_TAG=v0.13.5

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FONTDIR=${FONTDIR:-$HOME/.local/share/fonts}

# TrueType only. The release carries every face as ttf and as otf, and a machine holding both
# builds from a mixture of the two, which renders like neither.
FACES=(
  FiraSans-Regular FiraSans-Italic
  FiraSans-Medium FiraSans-MediumItalic
  FiraSans-SemiBold FiraSans-SemiBoldItalic
  FiraSans-Bold FiraSans-BoldItalic
  FiraMono-Regular FiraMono-Medium FiraMono-Bold
)
# The faces a browser needs, which is fewer: the site sets no semibold and no bold mono
WEB_FACES=(
  FiraSans-Regular FiraSans-Italic
  FiraSans-Medium FiraSans-MediumItalic
  FiraSans-Bold FiraSans-BoldItalic
  FiraMono-Regular
)
# Served whole beside the subsets, for readers that cannot open a woff2. Matplotlib is the one
# that matters: a figure drawn in a browser kernel fetches its face over HTTP from this directory.
TTF_FACES=(FiraSans-Regular FiraSans-Medium)
# Latin, the punctuation an economics paper sets, and the arrows and minus a caption may carry
SUBSET='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD'

fetch_firamath() {
  curl -sL -o "$1/FiraMath-Regular.otf" \
    "https://github.com/firamath/firamath/releases/download/$FIRAMATH_TAG/FiraMath-Regular.otf"
}

fetch_fira() {
  local dest=$1 face
  curl -sL -o "$dest/fira.zip" "https://github.com/mozilla/Fira/archive/refs/tags/$FIRA_TAG.zip"
  local globs=()
  for face in "${FACES[@]}"; do globs+=("*/ttf/$face.ttf"); done
  unzip -q -j "$dest/fira.zip" "${globs[@]}" -d "$dest"
  rm -f "$dest/fira.zip"
}

case "${1:-}" in
  install)
    mkdir -p "$FONTDIR"
    fetch_fira "$FONTDIR"
    fetch_firamath "$FONTDIR"
    command -v fc-cache >/dev/null && fc-cache -f >/dev/null
    echo "installed Fira $FIRA_TAG and Fira Math $FIRAMATH_TAG into $FONTDIR"
    ;;
  webfonts)
    # fontTools does the subsetting and brotli writes the woff2. Either an environment that already
    # carries them or uv, which fetches them into a throwaway one, so nobody installs to run this.
    if command -v pyftsubset >/dev/null; then
      subset() { pyftsubset "$@"; }
      fonttools_py() { python3 -c "$1" "${@:2}"; }
    elif command -v uvx >/dev/null; then
      subset() { uvx --quiet --from 'fonttools[woff]' pyftsubset "$@"; }
      fonttools_py() { uvx --quiet --from 'fonttools[woff]' python -c "$1" "${@:2}"; }
    else
      echo "needs pyftsubset: install fonttools and brotli, or install uv" >&2
      exit 2
    fi
    # Recompressing rather than subsetting, so every table the file arrived with is still in it
    towoff2() {
      fonttools_py 'import sys
from fontTools.ttLib import TTFont
f = TTFont(sys.argv[1])
f.flavor = "woff2"
f.save(sys.argv[2])
if "MATH" not in TTFont(sys.argv[2]):
    sys.exit("the MATH table did not survive the conversion")' "$1" "$2"
    }
    scratch=$(mktemp -d)
    trap 'rm -rf "$scratch"' EXIT
    fetch_fira "$scratch"
    mkdir -p "$ROOT/fonts"
    for face in "${WEB_FACES[@]}"; do
      subset "$scratch/$face.ttf" --output-file="$ROOT/fonts/$face.woff2" --flavor=woff2 \
        --unicodes="$SUBSET" --layout-features=kern,liga,onum,tnum
    done
    # Fira Math goes over whole: its OpenType MATH table is what stretches a bracket around a sum,
    # and a subsetter asked for a character range is under no obligation to carry it through.
    fetch_firamath "$scratch"
    towoff2 "$scratch/FiraMath-Regular.otf" "$ROOT/fonts/FiraMath-Regular.woff2"
    for face in "${TTF_FACES[@]}"; do cp "$scratch/$face.ttf" "$ROOT/fonts/$face.ttf"; done
    # Temml writes MathML that Chromium does not lay out unaided, and ships the CSS that fixes it,
    # along with the script-capital face that CSS asks for by name. Both come from the release
    # rather than node_modules, so a consumer holding this repository alone can run this.
    for f in Temml-Local.css Temml.woff2; do
      curl -sL -o "$ROOT/fonts/$f" "https://raw.githubusercontent.com/ronkok/Temml/$TEMML_TAG/dist/$f"
    done
    mv "$ROOT/fonts/Temml-Local.css" "$ROOT/fonts/temml.css"
    echo "wrote ${#WEB_FACES[@]} subsets from Fira $FIRA_TAG, Fira Math $FIRAMATH_TAG and temml.css into fonts/"
    ;;
  *)
    sed -n '2,8p' "${BASH_SOURCE[0]}"
    exit 2
    ;;
esac
