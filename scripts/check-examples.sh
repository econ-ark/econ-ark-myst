#!/usr/bin/env bash
# Build the examples and check what they PRODUCED, not only that the build exited 0.
#
#   scripts/check-examples.sh              build, then check the exported PDFs
#   scripts/check-examples.sh --self-test  seed each defect and confirm it is caught
#
# myst exits 0 even when typst fails and no PDF is written, and an unresolved
# cross-reference prints a literal "??" that no compiler log reports. So every
# check below reads the exported PDF text.

set -uo pipefail

ROOT=${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
EXAMPLES="$ROOT/examples"
PAPER="$EXAMPLES/exports/paper.pdf"
MINIMAL="$EXAMPLES/_build/exports/minimal.pdf"
TALL="$EXAMPLES/_build/exports/tall-table.pdf"

# Text the full example must contain; each is produced by a different template feature.
ANCHORS=(
  'Buffer Stock Saving with Heterogeneous'
  'Materials'
  'BufferStockTheory'
  'BibTeX'
  'JEL codes'
  '2.1.1 Sources of the parameters'
  'Proposition 1 (Concavity)'
  'Admonitions take a rule in the palette'
  'Declarations'
  'Carroll 1997'
  'References'
  'The Quarterly Journal of Economics 112 (1): 1'
  'zenodo.0000000'
  'Appendix A derives the Euler'
  'Appendix A Derivation'
  'Key points'
  'Cite as'
  'Working paper'
  'arXiv:2609.00000'
  'Summary'
  'MIT license'
  'Econ-ARK Working Papers 1 (3)'
  'Department of Economics, Johns Hopkins'
  'Computational Economics Grant (G-2026-00001)'
  "1990$(printf '\342\200\231')s"
)

PRIME=$(printf '\342\200\262')

fail=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=1; }
# Empty rather than zero when the file is not a PDF, so a caller's loop runs no iterations
page_count() { pdfinfo "$1" 2>/dev/null | awk '/^Pages:/ {print $2}'; }

check_text() {
  local name=$1 text=$2 a
  shift 2
  if [ -z "$text" ]; then
    bad "$name: no text extracted"
    return
  fi
  if grep -q '??' <<<"$text"; then
    bad "$name: unresolved reference: $(grep -m1 '??' <<<"$text")"
  else
    ok "$name: no unresolved references"
  fi
  # Typst sets ' after a digit as a prime (U+2032); the template restores the apostrophe
  if grep -q "[0-9]$PRIME" <<<"$text"; then
    bad "$name: prime instead of apostrophe: $(grep -m1 "[0-9]$PRIME" <<<"$text")"
  else
    ok "$name: no prime after a digit"
  fi
  for a in "$@"; do
    if grep -qF -- "$a" <<<"$text"; then ok "$name: contains '$a'"; else bad "$name: missing '$a'"; fi
  done
}

check_pdf() {
  local name=$1 pdf=$2
  shift 2
  if [ ! -s "$pdf" ]; then
    bad "$name: $pdf was not written"
    return
  fi
  check_text "$name" "$(pdftotext "$pdf" - 2>/dev/null)" "$@"
  if pdfinfo "$pdf" 2>/dev/null | grep -q '^CreationDate'; then
    bad "$name: PDF carries a creation timestamp, so rebuilds will not be byte-identical"
  else
    ok "$name: no creation timestamp"
  fi
}

# One line per page, as "<page> <text>", with the page's whitespace collapsed so it stays one line.
# The checks below differ only in what they do with each page, so the walk lives here.
page_lines() {
  local pdf=$1 pages p
  pages=$(page_count "$pdf")
  for ((p = 1; p <= ${pages:-0}; p++)); do
    printf '%d %s\n' "$p" "$(pdftotext -layout -f "$p" -l "$p" "$pdf" - 2>/dev/null | tr -s '[:space:]' ' ')"
  done
}

# A table taller than a page must break: its first and last rows land on different pages.
# An unbreakable one overflows the page foot, where its rows still extract as text, so a text search misses it.
check_breaks() {
  local name=$1 pdf=$2 first=$3 last=$4 p text pfirst="" plast=""
  while read -r p text; do
    grep -qF -- "$first" <<<"$text" && [ -z "$pfirst" ] && pfirst=$p
    grep -qF -- "$last" <<<"$text" && plast=$p
  done < <(page_lines "$pdf")
  if [ -n "$pfirst" ] && [ -n "$plast" ] && [ "$plast" -gt "$pfirst" ]; then
    ok "$name: table breaks from page $pfirst to page $plast"
  else
    bad "$name: '$first' and '$last' are not on successive pages (pages ${pfirst:-none} and ${plast:-none}), so the table did not break"
  fi
}

# A caption above a table that breaks must stay on the page where the table's first row is
check_same_page() {
  local name=$1 pdf=$2 caption=$3 row=$4 p text pcap="" prow=""
  while read -r p text; do
    [ -z "$pcap" ] && grep -qF -- "$caption" <<<"$text" && pcap=$p
    [ -z "$prow" ] && grep -qF -- "$row" <<<"$text" && prow=$p
  done < <(page_lines "$pdf")
  if [ -n "$pcap" ] && [ "$pcap" = "$prow" ]; then
    ok "$name: caption and first row share page $pcap"
  else
    bad "$name: caption on page ${pcap:-none} but first row on page ${prow:-none}, so the caption is orphaned"
  fi
}

# Typst warns about this template's own files and about the packages it imports alike, and the
# packages are noisy: scienceicons alone warns once per icon. Only a warning that names a file of
# this repository is ours to fix, so those fail the run and the rest are counted.
check_warnings() {
  local name=$1 log=$2 locations ours theirs
  # A warning names its file on the line below it, as "┌─ path.typ:line:column"; a package path
  # carries its own colons, so match the file suffix rather than splitting on them. awk counts
  # them, because NF skips the blank line a here-string adds and grep -vc would count it.
  locations=$(grep -oE '─ .*\.typ:[0-9]+:[0-9]+' "$log" 2>/dev/null)
  read -r ours theirs < <(awk 'NF { if (index($0, "@preview/")) t++; else o++ }
    END { print o + 0, t + 0 }' <<<"$locations")
  if [ "${ours:-0}" -eq 0 ]; then
    ok "$name: the build warns about no file of this template ($theirs from imported packages)"
  else
    bad "$name: $ours build warnings name files of this template:"
    grep -v '@preview/' <<<"$locations" | head -10
  fi
}

# Colour is what an admonition's styling changes, and pdftotext reads none of it. Rasterise the
# page and look for the rule the template draws beside a word, in the exact colour it uses.
check_rule() {
  local name=$1 pdf=$2 word=$3 colour=$4 hit page x0 y0 w h scratch n
  hit=$(pdftotext -bbox "$pdf" - 2>/dev/null | awk -v w=">$word</word>" '
    /<page / { p++ }
    index($0, w) { print p, $0; exit }')
  if [ -z "$hit" ]; then
    bad "$name: '$word' is not in the PDF, so its rule cannot be checked"
    return
  fi
  page=${hit%% *}
  # 150 dpi over the PDF's 72pt: a 20pt band to the left of the word, a little taller than its line
  read -r x0 y0 w h < <(sed -E 's/.*xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="[0-9.]+" yMax="([0-9.]+)".*/\1 \2 \3/' <<<"$hit" |
    awk '{ printf "%d %d %d %d\n", ($1 - 20) * 150 / 72, ($2 - 4) * 150 / 72, 20 * 150 / 72, ($3 - $2 + 8) * 150 / 72 }')
  scratch=$(mktemp -d)
  pdftoppm -png -r 150 -f "$page" -l "$page" "$pdf" "$scratch/page" 2>/dev/null
  n=$(convert "$scratch"/page-*.png -crop "${w}x${h}+${x0}+${y0}" +repage txt: 2>/dev/null | grep -c "${colour#\#}")
  rm -rf "$scratch"
  if [ "${n:-0}" -gt 0 ]; then
    ok "$name: '$word' carries a $colour rule ($n pixels)"
  else
    bad "$name: no $colour pixel beside '$word', so the rule is missing or off palette"
  fi
}

# fonts.sh fetches Temml's stylesheet from a release tag and package.json pins the library the
# plugin bundles. They render the same markup, so a build where they disagree styles MathML with
# a sheet from one version and lays it out with another.
check_temml_pin() {
  local name=$1 script=$2 pkg=$3 tag version
  tag=$(sed -nE 's/^TEMML_TAG=v?(.+)$/\1/p' "$script")
  version=$(jq -r '.dependencies.temml // empty' "$pkg" 2>/dev/null)
  if [ -n "$tag" ] && [ "$tag" = "$version" ]; then
    ok "$name: fonts.sh and package.json both pin Temml $tag"
  else
    bad "$name: fonts.sh pins Temml '${tag:-none}' and package.json '${version:-none}'"
  fi
}

# The README shows the site block a consumer should write, and this repository's myst.yml is that
# block. Two copies of one thing drift, and the copy a reader trusts is the one in the README.
check_documented_config() {
  local name=$1 readme=$2 config=$3 line missing=0 checked=0
  while IFS= read -r line; do
    [ -n "${line// /}" ] || continue
    checked=$((checked + 1))
    grep -qxF "$line" "$config" || { bad "$name: README shows '$line', which $config does not"; missing=1; }
  done < <(awk '/^site:$/ { on = 1 } on && /^```$/ { exit } on' "$readme")
  if [ "$missing" -eq 0 ] && [ "$checked" -gt 0 ]; then
    ok "$name: every line of the README's site block is in myst.yml ($checked lines)"
  elif [ "$checked" -eq 0 ]; then
    bad "$name: found no site block in $readme, so this check proved nothing"
  fi
}

# Before asking which file serves a weight, ask whether the family is there at all. A missing one
# is not a tie: Typst falls back to a bundled face, and the text rewraps.
check_family() {
  local name=$1 listing=$2 family=$3
  if grep -qxF "$family" <<<"$listing"; then
    ok "$name: Typst finds $family"
  else
    bad "$name: Typst does not find $family, so the build falls back to a bundled face"
  fi
}

# Counting family names proves nothing: a machine carrying the whole Fira family reports one name
# over twenty files. What decides a build is how many files offer the weight being asked for, since
# two offering the same one leaves the choice to whichever the machine reached first.
check_weight_files() {
  local name=$1 variants=$2 family=$3 style=$4 weight=$5 n
  n=$(awk -v fam="$family" -v want="Style: $style, Weight: $weight," '
    /^[A-Za-z]/ { infam = ($0 == fam) }
    infam && index($0, want) { n++ }
    END { print n + 0 }' <<<"$variants")
  if [ "$n" -eq 1 ]; then
    ok "$name: one file offers $family $style $weight"
  else
    bad "$name: $n files offer $family $style $weight, so the build picks by discovery order"
  fi
}

# A weight that no installed file carries sits between two that do, and Typst breaks that tie by
# the order it found the files in, which is the filesystem's. Reading the embedded fonts catches
# that re-resolution, which otherwise surfaces as an unexplained text diff.
check_font() {
  local name=$1 pdf=$2 font=$3
  if pdffonts "$pdf" 2>/dev/null | awk 'NR>2 { print $1 }' | sed 's/^[A-Z]*+//' | grep -qx "$font"; then
    ok "$name: the PDF embeds $font"
  else
    bad "$name: $font is not embedded in the PDF, so a weight resolved to another file"
  fi
}

# The tracked PDF must be what the current sources produce, and what it produces is pages, so the
# pages are what gets compared. Text alone misses a weight or a colour that changed; bytes alone
# over-reach, since a subset tag and an XMP instance id can differ between two identical renders.
check_tracked() {
  local name=$1 fresh=$2 committed=$3 scratch pages p differing total=0
  if ! diff <(pdftotext -layout "$committed" - 2>/dev/null) <(pdftotext -layout "$fresh" - 2>/dev/null) >/dev/null; then
    bad "$name: the tracked PDF's text differs from the fresh build; commit the rebuilt file:"
    diff <(pdftotext -layout "$committed" - 2>/dev/null) <(pdftotext -layout "$fresh" - 2>/dev/null) | head -20
    return
  fi
  if cmp -s "$committed" "$fresh"; then
    ok "$name: the tracked PDF is byte for byte what the sources produce"
    return
  fi
  scratch=$(mktemp -d)
  pdftoppm -png -r 150 "$committed" "$scratch/old" 2>/dev/null
  pdftoppm -png -r 150 "$fresh" "$scratch/new" 2>/dev/null
  pages=$(page_count "$fresh")
  for ((p = 1; p <= ${pages:-0}; p++)); do
    differing=$(compare -metric AE "$scratch"/old-"$p".png "$scratch"/new-"$p".png null: 2>&1)
    total=$((total + ${differing%%[!0-9]*}))
  done
  rm -rf "$scratch"
  if [ "$total" -eq 0 ]; then
    ok "$name: the tracked PDF renders identically to the fresh build (${pages:-0} pages, bytes differ)"
  else
    bad "$name: the tracked PDF renders differently from the fresh build ($total pixels); commit the rebuilt file"
  fi
}

# The bundle is what another repository loads over the network, and the site here builds from the
# source file instead, so the bundle can fall behind without anything failing. Every dependency it
# inlines is pinned exactly, which is what lets this compare bytes.
check_bundle() {
  local name=$1 bundle=$2 fresh
  fresh=$(mktemp)
  if ! (cd "$ROOT" && npx --no-install esbuild plugins/fira-math.mjs --bundle --format=esm \
    --platform=node --outfile="$fresh" --allow-overwrite) >/dev/null 2>&1; then
    bad "$name: esbuild did not run, so the published bundle went unchecked"
    rm -f "$fresh"
    return
  fi
  if cmp -s "$bundle" "$fresh"; then
    ok "$name: the committed bundle is what the plugin source produces"
  else
    bad "$name: $bundle differs from a fresh build, so the published plugin is stale"
  fi
  rm -f "$fresh"
}

# A stylesheet naming a file the site does not serve fails silently: the browser drops that face
# and paints the next one down. Temml's own sheet asks for a script-capital woff2 by name, which is
# how this repository shipped a dangling reference until a consumer building from it noticed.
check_css_urls() {
  local name=$1 dir=$2 sheet url target missing=0 seen=0
  while IFS= read -r sheet; do
    while IFS= read -r url; do
      [ -n "$url" ] || continue
      # A fragment is an id in the same document, and %23 is how one reads inside a data URI
      case "$url" in data:*|http:*|https:*|/*|'#'*|%23*) continue ;; esac
      seen=$((seen + 1))
      target="$(dirname "$sheet")/${url%%[?#]*}"
      [ -f "$target" ] || { bad "$name: $sheet asks for $url, which the site does not serve"; missing=1; }
      # A data URI carries its own url() inside it, so drop those before looking for real ones
    done < <(sed -E 's/url\("data:[^"]*"\)//g; s/url\(data:[^)]*\)//g' "$sheet" |
      sed -nE "s/.*url\((['\"]?)([^'\")]+)\1\).*/\2/p")
  done < <(find "$dir" -name 'myst-theme.css' -o -path '*/fonts/*.css' 2>/dev/null)
  if [ "$missing" -eq 0 ] && [ "$seen" -gt 0 ]; then
    ok "$name: every url() in the served stylesheets resolves ($seen references)"
  elif [ "$seen" -eq 0 ]; then
    bad "$name: no url() found in any stylesheet under $dir, so this check proved nothing"
  fi
}

# A block whose kind no renderer claims still builds: the theme prints its own "Invalid block"
# panel into the page and exits 0. article-theme claims none of these kinds at all, so a landing
# page built under the wrong theme comes out as plain headings and paragraphs.
check_landing() {
  local name=$1 dir=$2 blocks
  blocks=$(grep -o 'myst-landing-block' "$dir/index.html" 2>/dev/null | wc -l)
  if [ "$blocks" -ge 3 ] && ! grep -q 'Invalid block' "$dir/index.html" 2>/dev/null; then
    ok "$name: the landing page renders $blocks blocks, none of them invalid"
  else
    bad "$name: $blocks landing blocks under $dir, or one the theme rejected"
  fi
}

# The site half is an artifact too: the stylesheet and the banner must reach the built site, and
# the two themes must keep writing the classes the stylesheet reaches the paper through. A theme
# that renamed them would serve the stylesheet and ignore it.
check_site() {
  local name=$1 dir=$2 css banner html
  css=$(find "$dir" -name 'theme-*.css' -size +1k 2>/dev/null | head -1)
  if [ -n "$css" ] && grep -q -- '--ark-blue' "$css"; then
    ok "$name: the site serves theme.css"
  else
    bad "$name: no theme-*.css carrying the palette under $dir, so the site is unstyled"
  fi
  banner=$(find "$dir" -name 'banner-*.svg' 2>/dev/null | head -1)
  if [ -n "$banner" ] && grep -q 'fbaf3f' "$banner"; then
    ok "$name: the site serves banner.svg"
  else
    bad "$name: no banner-*.svg under $dir, so the paper has no banner"
  fi
  # The night lockup is a separate file, so a site can serve the day one and still go dark-blind
  if find "$dir" -name 'logo-dark-*.png' 2>/dev/null | grep -q .; then
    ok "$name: the site serves the night logo"
  else
    bad "$name: no logo-dark-*.png under $dir, so the wordmark vanishes at night"
  fi
  if [ -s "$dir/favicon.ico" ]; then
    ok "$name: the site serves the favicon"
  else
    bad "$name: no favicon.ico under $dir, so the tab carries MyST's own mark"
  fi
  html=$(cat "$dir"/index.html "$dir"/*/index.html 2>/dev/null)
  # The class list must hold "article" as a whole token, which "article-grid" alone does not give
  if grep -oE '<article[^>]*>' <<<"$html" | grep -qE 'class="([^"]* )?article( [^"]*)?"'; then
    ok "$name: the paper carries the class the stylesheet styles"
  else
    bad "$name: no <article class=\"... article ...\"> under $dir, so every article.article rule is inert"
  fi
  # The faces are built rather than tracked, so a site can be published complete in every other
  # way and still fall back to the system sans, which no page of it would report
  if [ "$(find "$dir" -name 'FiraSans-*.woff2' 2>/dev/null | wc -l)" -ge 4 ]; then
    ok "$name: the site serves the faces theme.css asks for"
  else
    bad "$name: fewer than four FiraSans woff2 under $dir, so readers get the system sans"
  fi
  # Fira Math and Temml's stylesheet travel together: the font is what a browser lays the symbols
  # out from, the stylesheet is what draws the parts of MathML that Chromium leaves undrawn
  if find "$dir" -name 'FiraMath-Regular*.woff2' 2>/dev/null | grep -q . &&
    find "$dir" -name 'temml*.css' 2>/dev/null | grep -q .; then
    ok "$name: the site serves the math face and the stylesheet that completes it"
  else
    bad "$name: no FiraMath woff2 or no temml css under $dir, so equations fall back to a system math font"
  fi
  # The plugin is the only thing putting MathML on the page. Were it to stop loading the build
  # would still succeed and every equation would quietly come back in KaTeX's Computer Modern,
  # which is legible enough that nothing else here would notice.
  if grep -q '<math' <<<"$html" && ! grep -q 'class="katex-html"' <<<"$html"; then
    ok "$name: the equations reach the page as MathML, which is what can take Fira Math"
  else
    bad "$name: no <math> under $dir, or KaTeX markup still present, so equations are not in Fira Math"
  fi
  # article-theme takes its downloads from the project, not from the paper's frontmatter, so a
  # paper that lists them still reaches a reader with no way to the PDF unless the project does too
  if find "$dir" -name 'paper-*.pdf' 2>/dev/null | grep -q .; then
    ok "$name: the site serves the paper as a download"
  else
    bad "$name: no paper-*.pdf under $dir, so a reader of the site cannot reach the PDF"
  fi
  # The softer page is painted over the theme's own white, which the theme writes as a utility
  # class. A theme that renamed it would take its whites back and leave the page half soft.
  if grep -qE 'class="[^"]*bg-white' <<<"$html"; then
    ok "$name: the theme still paints its surfaces with the class the softer page overrides"
  else
    bad "$name: no bg-white class under $dir, so the rules that soften the theme's whites are inert"
  fi
  # theme.css relabels the summary part by hanging on an id the theme writes. A rename upstream
  # would leave the rule inert and the site back to "Plain Language Summary", with nothing said.
  if grep -q 'id="summary"' <<<"$html"; then
    ok "$name: the summary part still carries the id theme.css relabels it through"
  else
    bad "$name: no id=\"summary\" under $dir, so the site says Plain Language Summary again"
  fi
  check_css_urls "$name" "$dir"
  if grep -qE 'myst-fm-parts|id="skip-to-article"' <<<"$html"; then
    ok "$name: the front matter carries the anchor the four-colour rule hangs on"
  else
    bad "$name: neither myst-fm-parts nor skip-to-article under $dir, so the four-colour rule is missing"
  fi
}

# A widened figure's caption starts over the margin rail, left of the text column at x = 153pt
check_left_of() {
  local name=$1 pdf=$2 word=$3 limit=$4 x
  x=$(pdftotext -bbox "$pdf" - 2>/dev/null | grep -F -- ">$word</word>" | head -1 | sed -E 's/.*xMin="([0-9.]+)".*/\1/')
  if [ -n "$x" ] && awk -v x="$x" -v l="$limit" 'BEGIN { exit !(x < l) }'; then
    ok "$name: '$word' starts at x = ${x%%.*}pt, over the margin rail"
  else
    bad "$name: '$word' starts at x = ${x:-none}pt, not left of ${limit}pt, so the figure was not widened"
  fi
}

self_test() {
  local good seeded out
  good=$(pdftotext "$PAPER" - 2>/dev/null)
  [ -n "$good" ] || { echo "self-test needs a built $PAPER"; exit 2; }

  # Capture first: piping into grep -q closes the pipe early, and pipefail then reports the check as failed
  seeded="$good"$'\n''See Section ??.'
  out=$(check_text seeded "$seeded" "${ANCHORS[@]}")
  if grep -q 'FAIL.*unresolved' <<<"$out"; then
    ok "self-test: a literal ?? is caught"
  else
    bad "self-test: a literal ?? went undetected"
  fi

  seeded="$good"$'\n'"Table 1${PRIME}s parameters."
  out=$(check_text seeded "$seeded" "${ANCHORS[@]}")
  if grep -q 'FAIL.*prime' <<<"$out"; then
    ok "self-test: a prime after a digit is caught"
  else
    bad "self-test: a prime after a digit went undetected"
  fi

  seeded=${good//Proposition 1 (Concavity)/}
  out=$(check_text seeded "$seeded" "${ANCHORS[@]}")
  if grep -q "FAIL.*missing 'Proposition 1" <<<"$out"; then
    ok "self-test: a missing anchor is caught"
  else
    bad "self-test: a missing anchor went undetected"
  fi

  # The calibration table in the full example fits on one page, so its first and last rows share a page
  out=$(check_breaks seeded "$PAPER" 'Discount factor' 'Relative risk aversion')
  if grep -q 'FAIL.*did not break' <<<"$out"; then
    ok "self-test: a table that stays on one page is caught"
  else
    bad "self-test: a table that stays on one page went undetected"
  fi

  # The full example's table caption sits in the text column, so it must fail the widened-figure test
  out=$(check_left_of seeded "$PAPER" 'Baseline' 100)
  if grep -q 'FAIL.*not widened' <<<"$out"; then
    ok "self-test: a figure left at text width is caught"
  else
    bad "self-test: a figure left at text width went undetected"
  fi

  out=$(check_pdf seeded "$EXAMPLES/exports/does-not-exist.pdf")
  if grep -q 'FAIL.*not written' <<<"$out"; then
    ok "self-test: a missing PDF is caught"
  else
    bad "self-test: a missing PDF went undetected"
  fi

  # The tall table's caption and its last row are pages apart, so they must read as orphaned
  out=$(check_same_page seeded "$TALL" 'Every case, one row each.' 'Case 35 A description')
  if grep -q 'FAIL.*orphaned' <<<"$out"; then
    ok "self-test: an orphaned caption is caught"
  else
    bad "self-test: an orphaned caption went undetected"
  fi

  # Typst stamps a creation date unless the template clears it, so a plain compile seeds the defect
  local scratch
  scratch=$(mktemp -d)
  printf 'A page.\n' >"$scratch/stamped.typ"
  if typst compile "$scratch/stamped.typ" "$scratch/stamped.pdf" >/dev/null 2>&1; then
    out=$(check_pdf seeded "$scratch/stamped.pdf" 'A page.')
    if grep -q 'FAIL.*creation timestamp' <<<"$out"; then
      ok "self-test: a creation timestamp is caught"
    else
      bad "self-test: a creation timestamp went undetected"
    fi
  else
    bad "self-test: could not compile a timestamped PDF to seed the check"
  fi
  rm -rf "$scratch"

  # Two different PDFs stand in for a tracked file left behind by its sources
  out=$(check_tracked seeded "$PAPER" "$TALL")
  if grep -q "FAIL.*text differs" <<<"$out"; then
    ok "self-test: a stale tracked PDF is caught"
  else
    bad "self-test: a stale tracked PDF went undetected"
  fi

  # The same words at another weight: the text check reads them as equal, so only the pages differ
  local weights
  weights=$(mktemp -d)
  printf '#set text(font: "Fira Sans", weight: 500)\nSame words either way.\n' >"$weights/light.typ"
  printf '#set text(font: "Fira Sans", weight: 700)\nSame words either way.\n' >"$weights/heavy.typ"
  if typst compile "$weights/light.typ" "$weights/light.pdf" >/dev/null 2>&1 &&
    typst compile "$weights/heavy.typ" "$weights/heavy.pdf" >/dev/null 2>&1; then
    out=$(check_tracked seeded "$weights/heavy.pdf" "$weights/light.pdf")
    if grep -q 'FAIL.*renders differently' <<<"$out"; then
      ok "self-test: a PDF whose text matches but whose pages differ is caught"
    else
      bad "self-test: a PDF whose text matches but whose pages differ went undetected"
    fi
  else
    bad "self-test: could not compile the two weights that seed the render check"
  fi
  rm -rf "$weights"

  # The exact shape of the bug this repository shipped: a stylesheet naming a font beside it that
  # the site never serves. Temml's sheet does this, which is why fonts.sh now fetches both.
  local cssdir
  cssdir=$(mktemp -d)
  printf '@font-face { src: url("Temml.woff2") format("woff2"); }\n' >"$cssdir/myst-theme.css"
  out=$(check_css_urls seeded "$cssdir")
  if grep -q 'FAIL.*does not serve' <<<"$out"; then
    ok "self-test: a stylesheet asking for a file the site lacks is caught"
  else
    bad "self-test: a stylesheet asking for a file the site lacks went undetected"
  fi
  : >"$cssdir/Temml.woff2"
  out=$(check_css_urls seeded "$cssdir")
  if grep -q 'ok.*resolves' <<<"$out"; then
    ok "self-test: a stylesheet whose files are all served passes"
  else
    bad "self-test: a stylesheet whose files are all served was reported missing"
  fi
  rm -rf "$cssdir"

  out=$(check_temml_pin seeded "$ROOT/scripts/fonts.sh" /dev/null)
  if grep -q "FAIL.*package.json 'none'" <<<"$out"; then
    ok "self-test: Temml pins that disagree are caught"
  else
    bad "self-test: Temml pins that disagree went undetected"
  fi

  # A landing page built under a theme that claims none of the block kinds, which is what
  # article-theme does: the blocks come out as ordinary headings with no wrapper at all
  local land
  land=$(mktemp -d)
  printf '<div class="myst-landing-block">one</div>\n<p>Invalid block</p>\n' >"$land/index.html"
  out=$(check_landing seeded "$land")
  if grep -q 'FAIL.*landing blocks under' <<<"$out"; then
    ok "self-test: a landing page whose blocks the theme rejected is caught"
  else
    bad "self-test: a landing page whose blocks the theme rejected went undetected"
  fi
  rm -rf "$land"

  # The README documenting a key the config no longer carries, which is how these two drift
  local conf
  conf=$(mktemp)
  printf 'site:\n  template: book-theme\n' >"$conf"
  out=$(check_documented_config seeded "$ROOT/README.md" "$conf")
  if grep -q 'FAIL.*README shows' <<<"$out"; then
    ok "self-test: a README documenting a key the config lacks is caught"
  else
    bad "self-test: a README documenting a key the config lacks went undetected"
  fi
  rm -f "$conf"

  # A machine that never had Fira Math installed, which is what scripts/fonts.sh install prevents
  out=$(check_family seeded "$(printf 'Fira Sans\nFira Mono\nDejaVu Sans Mono\n')" "Fira Math")
  if grep -q 'FAIL.*does not find Fira Math' <<<"$out"; then
    ok "self-test: a missing font family is caught"
  else
    bad "self-test: a missing font family went undetected"
  fi

  # A font directory holding the release twice, which is what a mixed ttf and otf install looks like
  out=$(check_weight_files seeded "$(printf 'Fira Sans\n  |- /a/FiraSans-Medium.ttf\n      Style: Normal, Weight: 500, Stretch: 100%%\n  |- /b/FiraSans-Medium.otf\n      Style: Normal, Weight: 500, Stretch: 100%%\n')" "Fira Sans" Normal 500)
  if grep -q 'FAIL.*2 files offer' <<<"$out"; then
    ok "self-test: two files offering one weight is caught"
  else
    bad "self-test: two files offering one weight went undetected"
  fi

  # Fira has no Black, so it stands for any weight that resolved to a file the template lacks
  out=$(check_font seeded "$PAPER" FiraSans-Black)
  if grep -q 'FAIL.*not embedded' <<<"$out"; then
    ok "self-test: a weight that resolved to another font file is caught"
  else
    bad "self-test: a weight that resolved to another font file went undetected"
  fi

  # A log carrying a warning about a file of this template, beside the packages' own noise
  local log
  log=$(mktemp)
  printf 'warning: unknown variable\n  ┌─ econark.typ:12:3\nwarning: no whitespace\n  ┌─ @preview/scienceicons:0.1.0/index.typ:2:20\n' >"$log"
  out=$(check_warnings seeded "$log")
  if grep -q 'FAIL.*name files of this template' <<<"$out"; then
    ok "self-test: a build warning about this template is caught"
  else
    bad "self-test: a build warning about this template went undetected"
  fi
  printf 'warning: no whitespace\n  ┌─ @preview/scienceicons:0.1.0/index.typ:2:20\n' >"$log"
  out=$(check_warnings seeded "$log")
  if grep -q 'ok.*imported packages' <<<"$out"; then
    ok "self-test: a package's own warnings pass"
  else
    bad "self-test: a package's own warnings failed the run"
  fi
  # A build that warned about nothing at all, which is the case the counting used to get wrong
  : >"$log"
  out=$(check_warnings seeded "$log")
  if grep -q 'ok.*(0 from imported packages)' <<<"$out"; then
    ok "self-test: a build with no warnings passes and counts none"
  else
    bad "self-test: a build with no warnings was miscounted: $out"
  fi
  rm -f "$log"

  # A word in the table has no rule beside it, so the colour check must report one missing
  out=$(check_rule seeded "$PAPER" 'Discount' '#1F476B')
  if grep -q 'FAIL.*off palette' <<<"$out"; then
    ok "self-test: a missing rule is caught"
  else
    bad "self-test: a missing rule went undetected"
  fi

  out=$(check_site seeded "$(mktemp -d)")
  if grep -q 'FAIL.*unstyled' <<<"$out" && grep -q 'FAIL.*no banner' <<<"$out" &&
    grep -q 'FAIL.*rule is inert' <<<"$out" && grep -q 'FAIL.*four-colour rule is missing' <<<"$out" &&
    grep -q 'FAIL.*vanishes at night' <<<"$out" && grep -q "FAIL.*MyST's own mark" <<<"$out" &&
    grep -q 'FAIL.*soften the theme' <<<"$out" && grep -q 'FAIL.*cannot reach the PDF' <<<"$out" &&
    grep -q 'FAIL.*system sans' <<<"$out" && grep -q 'FAIL.*system math font' <<<"$out" &&
    grep -q 'FAIL.*Plain Language Summary again' <<<"$out"; then
    ok "self-test: a site without the stylesheet, the banner, the logos or the classes it styles is caught"
  else
    bad "self-test: a site missing the stylesheet, the banner, the logos or its classes went undetected"
  fi

  # A bundle left behind by an edit to the plugin source, which is the way this one goes wrong
  local stale
  stale=$(mktemp)
  printf 'export default { name: "stale" };\n' >"$stale"
  out=$(check_bundle seeded "$stale")
  if grep -q 'FAIL.*is stale' <<<"$out"; then
    ok "self-test: a bundle that no longer matches the plugin source is caught"
  else
    bad "self-test: a bundle that no longer matches the plugin source went undetected"
  fi
  rm -f "$stale"

  # The case the MathML check exists for: a site whose equations came out of KaTeX after all
  local katexsite
  katexsite=$(mktemp -d)
  printf '<article class="article"><span class="katex"><span class="katex-html">v(m)</span></span></article>\n' \
    >"$katexsite/index.html"
  out=$(check_site seeded "$katexsite")
  if grep -q 'FAIL.*not in Fira Math' <<<"$out"; then
    ok "self-test: a site whose equations stayed in KaTeX is caught"
  else
    bad "self-test: a site whose equations stayed in KaTeX went undetected"
  fi
  rm -rf "$katexsite"

  # A theme that renamed the class would still serve the stylesheet, so the token check must be exact
  local scratchsite
  scratchsite=$(mktemp -d)
  printf '<article class="article-grid subgrid-gap">no article token</article>\n' >"$scratchsite/index.html"
  cp "$ROOT/theme.css" "$scratchsite/theme-0.css"
  cp "$ROOT/banner.svg" "$scratchsite/banner-0.svg"
  out=$(check_site seeded "$scratchsite")
  if grep -q 'FAIL.*rule is inert' <<<"$out"; then
    ok "self-test: a theme that dropped the article class is caught"
  else
    bad "self-test: a theme that dropped the article class went undetected"
  fi
  rm -rf "$scratchsite"
}

for tool in myst pdftotext pdfinfo pdffonts pdftoppm convert; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool"; exit 2; }
done

if [ "${1:-}" = "--self-test" ]; then
  self_test
else
  buildlog=$(mktemp)
  (cd "$ROOT" && rm -rf _build examples/_build && myst build --typst) >"$buildlog" 2>&1
  check_warnings build "$buildlog"
  rm -f "$buildlog"
  check_pdf paper "$PAPER" "${ANCHORS[@]}"
  check_pdf minimal "$MINIMAL" 'Minimal Example'
  check_pdf tall-table "$TALL" 'Case 35' 'Text after the table'
  check_breaks tall-table "$TALL" 'Case 1 A description' 'Case 35 A description'
  check_same_page tall-table "$TALL" 'Every case, one row each.' 'Case 1 A description'
  check_rule paper "$PAPER" 'Admonitions' '#1F476B'
  check_left_of tall-table "$TALL" 'Widecaption' 100
  check_left_of tall-table "$TALL" 'Widetablecaption' 100
  committed=$(mktemp)
  git -C "$ROOT" show HEAD:examples/exports/paper.pdf >"$committed" 2>/dev/null
  check_tracked paper "$PAPER" "$committed"
  rm -f "$committed"
  # The suffix names the embedding, which follows the file format: the release's ttf gives a bare
  # name and its otf an Identity-H one. A machine holding both formats builds from a mixture, and
  # the mixture renders differently from either, which is how these three came to disagree once.
  check_font paper "$PAPER" FiraSans-Medium
  check_font paper "$PAPER" FiraSans-Italic
  # The weights the template asks for, each of which must come from exactly one file
  variants=$(typst fonts --variants 2>/dev/null)
  families=$(typst fonts 2>/dev/null)
  for family in "Fira Sans" "Fira Mono" "Fira Math"; do
    check_family fonts "$families" "$family"
  done
  for weight in 400 500 700; do
    check_weight_files fonts "$variants" "Fira Sans" Normal "$weight"
    check_weight_files fonts "$variants" "Fira Sans" Italic "$weight"
  done
  check_weight_files fonts "$variants" "Fira Mono" Normal 400
  check_weight_files fonts "$variants" "Fira Math" Normal 400
  check_font paper "$PAPER" FiraMath-Regular-Identity-H
  check_bundle plugin "$ROOT/plugins/fira-math.bundle.mjs"
  check_temml_pin pins "$ROOT/scripts/fonts.sh" "$ROOT/package.json"
  check_documented_config docs "$ROOT/README.md" "$ROOT/myst.yml"
  (cd "$ROOT" && myst build --html) >/dev/null 2>&1
  check_site "site ($(awk '/^  template:/ { print $2; exit }' "$ROOT/myst.yml"))" "$ROOT/_build/html"
  # The stylesheet claims to dress either theme, so build the other one from a copy of the tree
  other=$(mktemp -d)
  # node_modules is linked rather than copied: the plugin has to resolve from the copy or its
  # equations come back as KaTeX, but copying it spends a tenth of a second on every run
  tar -c --exclude=_build --exclude=.git --exclude=./node_modules -C "$ROOT" . | tar -x -C "$other"
  ln -s "$ROOT/node_modules" "$other/node_modules"
  if grep -q 'template: article-theme' "$other/myst.yml"; then
    sed -i 's/template: article-theme/template: book-theme/' "$other/myst.yml"
    othername="book-theme"
  else
    sed -i 's/template: book-theme/template: article-theme/' "$other/myst.yml"
    othername="article-theme"
  fi
  (cd "$other" && myst build --html) >/dev/null 2>&1
  check_site "site ($othername)" "$other/_build/html"
  rm -rf "$other"
  # The landing page carries no paper, so check_site's banner, equation and download checks do not
  # apply to it. What it shares with the two demos is the stylesheet, the faces and the palette.
  (cd "$ROOT/landing" && myst build --html) >/dev/null 2>&1
  landdir="$ROOT/landing/_build/html"
  check_landing landing "$landdir"
  check_css_urls landing "$landdir"
  if [ "$(find "$landdir" -name 'FiraSans-*.woff2' 2>/dev/null | wc -l)" -ge 4 ]; then
    ok "landing: the site serves the faces theme.css asks for"
  else
    bad "landing: fewer than four FiraSans woff2 under $landdir, so readers get the system sans"
  fi
  if grep -q 'ark-blue' "$landdir"/myst-theme.css 2>/dev/null; then
    ok "landing: the site serves theme.css"
  else
    bad "landing: no palette in $landdir/myst-theme.css, so the landing page is undressed"
  fi
fi

exit $fail
