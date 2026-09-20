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
  # A part written last with nothing closing it costs the paper its footnotes, and MyST says so in
  # a line the Typst warning check never reads. These are the parts and people that go with it.
  'inverts the first-order condition'
  'For everyone who waited'
  'All models are wrong'
  'Rita Referee'
  'Eddie Editor'
  'Proposition 1 (Concavity)'
  'Admonitions take a rule in the palette'
  'Declarations'
  'Carroll 1997'
  # A grouped citation, which Chicago collapses to one author, and a reference to a figure, the one
  # target kind the ?? check never had an instance of
  'Carroll 1997; 2006'
  'Figure 1 shows it at that calibration'
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
  # The same digit and apostrophe inside a listing, where the curly quote belongs to prose alone:
  # a reader pastes code out of a PDF, and a rewritten quote is source that will not parse
  "# the 1990's calibration"
)

PRIME=$(printf '\342\200\262')
# The one colour asserted often enough to drift: a retuned blue must fail every one of these
ARK_BLUE='#1F476B'

# Rasterising a page costs about a quarter second and seven colour checks land on two pages, so the
# renders are kept. The key carries the file's size and mtime, so a rebuilt PDF misses rather than
# serving the image of the file it replaced.
RASTER_CACHE=$(mktemp -d)
trap 'rm -rf "$RASTER_CACHE"' EXIT

raster_page() {
  local pdf=$1 page=$2 key png
  key=$(stat -c '%s-%Y' "$pdf" 2>/dev/null)-$(printf '%s' "$pdf" | md5sum | cut -c1-8)-$page
  png="$RASTER_CACHE/$key.png"
  [ -f "$png" ] || pdftoppm -png -r 150 -f "$page" -l "$page" -singlefile "$pdf" "${png%.png}" 2>/dev/null
  printf '%s\n' "$png"
}

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
  # Anchors are matched against the text with its whitespace collapsed, since grep works a line at
  # a time and a phrase that wraps would otherwise read as missing. Whether a phrase is in the PDF
  # is the question; where the line happens to break is not, and an edit anywhere above can move it.
  local flat
  flat=$(tr '\n' ' ' <<<"$text" | tr -s '[:space:]' ' ')
  for a in "$@"; do
    if grep -qF -- "$a" <<<"$flat"; then ok "$name: contains '$a'"; else bad "$name: missing '$a'"; fi
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
# An unbreakable one overflows the foot, where rows still extract as text, so a search misses it.
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
  # A missing or empty log otherwise reads exactly like a clean build, and an empty one is what a
  # build that died before writing leaves. -a keeps the lines readable if the log ever goes binary,
  # where grep reports "Binary file matches" instead of them.
  if [ ! -s "$log" ]; then
    bad "$name: the build log is missing or empty, so this check proved nothing"
    return
  fi
  # A warning names its file on the line below it, as "┌─ path.typ:line:column"; a package path
  # carries its own colons, so match the file suffix rather than splitting on them. awk counts
  # them, because NF skips the blank line a here-string adds and grep -vc would count it.
  locations=$(grep -aoE '─ .*\.typ:[0-9]+:[0-9]+' "$log")
  read -r ours theirs < <(awk 'NF { if (index($0, "@preview/")) t++; else o++ }
    END { print o + 0, t + 0 }' <<<"$locations")
  if [ "${ours:-0}" -eq 0 ]; then
    ok "$name: the build warns about no file of this template ($theirs from imported packages)"
  else
    bad "$name: $ours build warnings name files of this template:"
    grep -v '@preview/' <<<"$locations" | head -10
  fi
}

# MyST reports its own troubles on lines of its own, which the check above never reads: that one
# looks for Typst compiler warnings and nothing else. A dropped footnote left the PDF missing text
# and said so only here, so the log is the cheaper of the two places to catch it.
check_myst_errors() {
  local name=$1 log=$2 errors
  if [ ! -s "$log" ]; then
    bad "$name: the build log is missing or empty, so this check proved nothing"
    return
  fi
  # -a so a log holding one truncated emoji still yields the matching lines themselves rather than
  # "Binary file matches", which would count as one error and print nothing useful.
  errors=$(grep -aF '⛔' "$log")
  if [ -z "$errors" ]; then
    ok "$name: MyST reports no errors of its own"
  else
    bad "$name: MyST reported $(wc -l <<<"$errors") errors of its own:"
    head -5 <<<"$errors"
  fi
}

# Colour is what these two read, and pdftotext reads none of it. Both find a word, rasterise its
# page and count pixels of an exact hex: check_rule in the band beside the word, where the template
# draws a rule, and check_ink over the word itself, where the branding is the ink.
check_swatch() {
  local name=$1 pdf=$2 word=$3 colour=$4 mode=$5 hit page x0 y0 w h n
  hit=$(pdftotext -bbox "$pdf" - 2>/dev/null | awk -v w=">$word</word>" '
    /<page / { p++ }
    index($0, w) { print p, $0; exit }')
  if [ -z "$hit" ]; then
    bad "$name: '$word' is not in the PDF, so its colour cannot be checked"
    return
  fi
  page=${hit%% *}
  # 150 dpi over the PDF's 72pt. Beside: a 20pt band left of the word, a little taller than its line
  read -r x0 y0 w h < <(sed -E 's/.*xMin="([0-9.]+)" yMin="([0-9.]+)" xMax="([0-9.]+)" yMax="([0-9.]+)".*/\1 \2 \3 \4/' <<<"$hit" |
    awk -v mode="$mode" '{
      s = 150 / 72
      if (mode == "beside") { printf "%d %d %d %d\n", ($1 - 20) * s, ($2 - 4) * s, 20 * s, ($4 - $2 + 8) * s }
      else { printf "%d %d %d %d\n", $1 * s, $2 * s, ($3 - $1) * s, ($4 - $2) * s }
    }')
  n=$(convert "$(raster_page "$pdf" "$page")" -crop "${w}x${h}+${x0}+${y0}" +repage txt: 2>/dev/null | grep -c "${colour#\#}")
  if [ "${n:-0}" -gt 0 ]; then
    if [ "$mode" = beside ]; then
      ok "$name: '$word' carries a $colour rule ($n pixels)"
    else
      ok "$name: '$word' is set in $colour ($n pixels)"
    fi
  elif [ "$mode" = beside ]; then
    bad "$name: no $colour pixel beside '$word', so the rule is missing or off palette"
  else
    bad "$name: '$word' carries no $colour pixel, so it is unbranded or off palette"
  fi
}

check_rule() { check_swatch "$1" "$2" "$3" "$4" beside; }

# Anti-aliasing softens a glyph's edges, so one pixel of the exact hex is enough
check_ink() { check_swatch "$1" "$2" "$3" "$4" self; }

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

# MyST accepts a pile of aliases for its part and frontmatter names, and a file mixing them with
# the canonical names reads as though the two named different things. The examples and the configs
# keep to what PAGE_KNOWN_PARTS and the frontmatter schema call them.
check_no_aliases() {
  local name=$1 hits
  shift
  hits=$(grep -nE '"(ack|acknowledgement|acknowledgements|acknowledgment|availability|dataAvailability|data-availability|quote|plain_language_summary|plain-language-summary|plainLanguageSummary|lay_summary|lay-summary|keyPoints|key_points|key-points)"|^[[:space:]]*(author|reviewer|editor|contributor|affiliation|export|download|part|identifier|socials|image):' "$@" 2>/dev/null)
  if [ -z "$hits" ]; then
    ok "$name: the examples and configs name every part and field as MyST does"
  else
    bad "$name: MyST aliases used where the canonical name belongs:"
    head -5 <<<"$hits"
  fi
}

# Italic leaves no trace in a PDF's text layer, so the list itself is what gets read. These are the
# kinds amsthm sets in its plain style that MyST also has a directive for; every other kind it
# knows belongs to the upright definition or remark styles.
check_italic_kinds() {
  local name=$1 file=$2 want='("theorem", "lemma", "proposition", "corollary", "conjecture", "criterion")'
  if grep -qF "#let italicKinds = $want" "$file"; then
    ok "$name: the italic proof kinds are amsthm's plain style"
  else
    bad "$name: italicKinds is not amsthm's plain style; found $(grep -F '#let italicKinds' "$file" | head -1)"
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
  local name=$1 fresh=$2 committed=$3 scratch pages p differing digits total=0
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
  # pdftoppm pads a page number to the width of the last one, so a paper reaching ten pages writes
  # old-01.png. compare prints its own failures on stdout, and a count read from one of those is
  # empty: that aborts the arithmetic and, with it, every check after this one.
  for ((p = 1; p <= ${pages:-0}; p++)); do
    differing=$(compare -metric AE \
      "$(printf '%s/old-%0*d.png' "$scratch" "${#pages}" "$p")" \
      "$(printf '%s/new-%0*d.png' "$scratch" "${#pages}" "$p")" null: 2>&1)
    digits=${differing%%[!0-9]*}
    if [ -z "$digits" ]; then
      rm -rf "$scratch"
      bad "$name: page $p of the tracked PDF could not be compared, so it is unchecked: $differing"
      return
    fi
    total=$((total + digits))
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
      case "$url" in data:*|http:*|https:*|'#'*|%23*) continue ;; esac
      seen=$((seen + 1))
      # A leading slash means the site root, not the stylesheet's directory. Skipping those left
      # --ark-hero-image: url("/banner.svg") unchecked on a landing that never served the file.
      case "$url" in
        /*) target="$dir/${url#/}" ;;
        *) target="$(dirname "$sheet")/$url" ;;
      esac
      target="${target%%[?#]*}"
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

# The landing branding is opt-in by class, which is why it needs its own check: the stylesheet can
# define .ark-hero and the page can stop asking for it, or the reverse, and every other check here
# still passes. Both ends of each class are asserted.
check_landing_classes() {
  local name=$1 dir=$2 css=$3 cls missing_html="" missing_css=""
  for cls in ark-hero ark-section ark-steps ark-ways; do
    grep -q "$cls" "$dir/index.html" 2>/dev/null || missing_html="$missing_html $cls"
    grep -q "\.$cls" "$css" 2>/dev/null || missing_css="$missing_css $cls"
  done
  if [ -z "$missing_html" ] && [ -z "$missing_css" ]; then
    ok "$name: the page and the stylesheet agree on all four landing classes"
  else
    bad "$name: absent from the page:${missing_html:- none}; absent from $css:${missing_css:- none}"
  fi
}

# A dropdown admonition or proof renders as `details`, every other one as `aside` (myst-theme,
# admonitions.tsx and proof.tsx). A selector qualified by the tag therefore brands nine kinds and
# silently misses the tenth, which is what theme.css did until 2026-09-19.
check_dropdown_tags() {
  local name=$1 dir=$2 css=$3 html
  html=$(cat "$dir"/index.html "$dir"/*/index.html 2>/dev/null)
  if ! grep -q '<details class="myst-admonition' <<<"$html"; then
    bad "$name: no dropdown admonition in the built pages, so the tag split goes untested"
    return
  fi
  if grep -qE '(^|[ ,])aside\.myst-(admonition|proof)' "$css"; then
    bad "$name: $css qualifies an admonition or proof with aside, which misses every dropdown"
  else
    ok "$name: admonition and proof rules reach both the aside and the details form"
  fi
}

# The theme's accent arrives as Tailwind utilities, so the override list in theme.css is only as
# good as the census it was written from. Deriving both sides here turns a guessed list into a
# checked one: a theme upgrade that paints with a new blue fails instead of leaking.
check_blue_coverage() {
  local name=$1 dir=$2 css=$3 rendered overridden missing
  rendered=$(rg -o --no-filename '[a-z:/-]*blue-[0-9]+(/[0-9]+)?' \
    "$dir"/index.html "$dir"/*/index.html 2>/dev/null | sort -u)
  if [ -z "$rendered" ]; then
    bad "$name: no blue utility in the built pages, so the override list goes untested"
    return
  fi
  # theme.css escapes the colon and the slash; strip the backslashes to compare like with like
  overridden=$(rg -o '\.[a-z0-9\\:/-]*blue-[0-9]+(\\/[0-9]+)?' "$css" |
    sed 's/^\.//; s/\\//g' | sort -u)
  missing=$(comm -23 <(echo "$rendered") <(echo "$overridden") | tr '\n' ' ')
  if [ -n "${missing// /}" ]; then
    bad "$name: $css leaves the theme's blue on: $missing"
  else
    ok "$name: every blue utility the pages render is overridden ($(wc -l <<<"$rendered") classes)"
  fi
}

# styles/button.css sets the label white over --myst-color-primary, so the fill has to keep coming
# from that token. The landing page carries a button outside the hero for this: one inside would sit
# on the banner field, where a theme colour reaching the fill would read as deliberate.
check_landing_button() {
  local name=$1 dir=$2
  if ! grep -q 'class="[^"]*button' "$dir/index.html" 2>/dev/null; then
    bad "$name: the landing page renders no button, so the fill rule goes untested"
    return
  fi
  # The served stylesheet, never the source: a build that failed to copy theme.css would pass a
  # source read. This reaches the base fill alone; hover resolves against the theme's nested `&`,
  # which no read of the files can settle, so that state is checked by hand. See docs/known-gaps.
  if grep -q 'background-color: var(--myst-color-primary)' "$dir/myst-theme.css" 2>/dev/null; then
    ok "$name: the served stylesheet still fills .button from the brand token"
  else
    bad "$name: $dir/myst-theme.css no longer fills .button from --myst-color-primary"
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

# The paper site and the landing site assert these two identically, so they share one definition.
# The `--` and the leading dashes are load bearing: a looser 'ark-blue' also matches a class name
# carrying the words, which passes a site whose palette never arrived.
check_theme_css_served() {
  local name=$1 dir=$2
  # The fixed name every page links, never build/theme-<hash>.css: mystmd re-emits each hash it has
  # ever built there, so five of the six under landing are stale and a find picks among them.
  if grep -q -- '--ark-blue' "$dir/myst-theme.css" 2>/dev/null; then
    ok "$name: the site serves theme.css"
  else
    bad "$name: $dir/myst-theme.css carries no palette, so the site is unstyled"
  fi
}

# The faces are built rather than tracked, so a site can be published complete in every other way
# and still fall back to the system sans, which no page of it would report
check_faces_served() {
  local name=$1 dir=$2
  if [ "$(find "$dir" -name 'FiraSans-*.woff2' 2>/dev/null | wc -l)" -ge 4 ]; then
    ok "$name: the site serves the faces theme.css asks for"
  else
    bad "$name: fewer than four FiraSans woff2 under $dir, so readers get the system sans"
  fi
}

# The site half is an artifact too: the stylesheet and the banner must reach the built site, and
# the two themes must keep writing the classes the stylesheet reaches the paper through. A theme
# that renamed them would serve the stylesheet and ignore it.
check_site() {
  local name=$1 dir=$2 banner html
  check_theme_css_served "$name" "$dir"
  banner=$(find "$dir" -name 'banner-*.svg' 2>/dev/null | head -1)
  if [ -n "$banner" ] && grep -q 'fbaf3f' "$banner"; then
    ok "$name: the site serves banner.svg"
  else
    bad "$name: no banner-*.svg under $dir, so the paper has no banner"
  fi
  # Both banner rules in theme.css stretch the artwork to its box, which only reaches the corners
  # while the file declines to preserve its ratio. Restore the default and the fan quietly
  # letterboxes into a strip instead, which no colour or geometry check here would notice.
  if [ -n "$banner" ] && grep -q 'preserveAspectRatio="none"' "$banner"; then
    ok "$name: the banner still stretches to its box"
  else
    bad "$name: the served banner preserves its ratio, so the fan will letterbox rather than fill"
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
  check_faces_served "$name" "$dir"
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
  # theme.css labels the declaration part through the class plugins/part-wrapper.mjs writes, the
  # part having no backmatter slot of its own. A plugin that stopped loading would drop the label
  # silently, and the paragraph would read as the last paragraph of the paper.
  if grep -q 'ark-part-declaration' <<<"$html"; then
    ok "$name: the declaration part still carries the class theme.css labels it through"
  else
    bad "$name: no ark-part-declaration under $dir, so the declarations show unlabelled"
  fi
  # The label and the body share one grid, and every paragraph of the part is a child of it. When
  # they were flex items instead, a second paragraph became a second column touching the first, and
  # each column read correctly alone, which hid it. The example keeps two so the shape ships.
  if grep -qP '<div class="ark-part-declaration"><p>[^<]*</p><p>' <<<"$html"; then
    ok "$name: the declaration part still carries the two paragraphs its layout is sized for"
  else
    bad "$name: the declaration part under $dir holds one paragraph, so the multi-paragraph layout is untested"
  fi
  # A definition list and a quotation are styled off the bare element, so the rules go inert the
  # moment the theme wraps either in something else, and the site drifts from the PDF unannounced
  if grep -q '<dt' <<<"$html" && grep -q '<blockquote' <<<"$html"; then
    ok "$name: the term and the quotation still reach the page as the elements theme.css styles"
  else
    bad "$name: no bare <dt> or <blockquote> under $dir, so those rules are inert and the site drifts from the PDF"
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

# The rail is placed from the foot of the page, so a rail too tall for its column grows up over the
# logo. Build a paper with more reviewers than it can hold and read where their names land: in the
# text column means the template moved them out, in the rail means they are sitting on the mark.
check_rail_overflow() {
  local name=$1 scratch x
  scratch=$(mktemp -d)
  {
    echo '---'
    echo 'title: Rail overflow'
    echo 'authors:'
    echo '  - name: A Person'
    echo 'reviewers:'
    # Enough names to pass the column on their own: this paper carries none of the citation,
    # correspondence, funding or licence blocks that fill a real one
    for i in $(seq 1 60); do echo "  - name: Reviewer Number $i"; done
    echo 'exports:'
    echo '  - format: typst'
    echo "    template: $ROOT"
    echo '    output: rail.pdf'
    echo '---'
    echo
    echo '# Body'
    echo
    echo 'Text.'
  } >"$scratch/rail.md"
  (cd "$scratch" && myst build rail.md --typst) >/dev/null 2>&1
  if [ ! -s "$scratch/rail.pdf" ]; then
    bad "$name: the overflow paper did not build, so the rail guard went unchecked"
    rm -rf "$scratch"
    return
  fi
  x=$(pdftotext -bbox "$scratch/rail.pdf" - 2>/dev/null | grep -F '>Number</word>' | head -1 |
    sed -E 's/.*xMin="([0-9.]+)".*/\1/')
  if [ -n "$x" ] && awk -v x="$x" 'BEGIN { exit !(x > 150) }'; then
    ok "$name: a rail it cannot hold moves the reviewers into the text column (x = ${x%%.*}pt)"
  else
    bad "$name: reviewers stayed in the rail at x = ${x:-none}pt, so the rail is over the logo"
  fi
  rm -rf "$scratch"
}

self_test() {
  local good seeded out
  good=$(pdftotext "$PAPER" - 2>/dev/null)
  [ -n "$good" ] || { echo "self-test needs a built $PAPER"; exit 2; }

  # Capture first: piping into grep -q closes the pipe early, and pipefail then reports a false fail
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

  # The calibration table in the full example fits one page, so its first and last rows share it
  out=$(check_breaks seeded "$PAPER" 'Discount factor' 'Relative risk aversion')
  if grep -q 'FAIL.*did not break' <<<"$out"; then
    ok "self-test: a table that stays on one page is caught"
  else
    bad "self-test: a table that stays on one page went undetected"
  fi

  # The full example's caption sits in the text column, so it must fail the widened-figure test
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
  # The root-relative branch, which this check used to skip outright: a url("/x.svg") that the
  # site root lacks has to fail, and the same one has to pass once the file is there.
  printf '@font-face { src: url("Temml.woff2") format("woff2"); }\n.h{background:url("/banner.svg")}\n' >"$cssdir/myst-theme.css"
  if grep -q 'FAIL.*asks for /banner.svg' <<<"$(check_css_urls seeded "$cssdir")"; then
    ok "self-test: a stylesheet asking for a root-relative file the site lacks is caught"
  else
    bad "self-test: a root-relative url() the site does not serve went undetected"
  fi
  : >"$cssdir/banner.svg"
  if grep -q 'ok.*resolves (2 references)' <<<"$(check_css_urls seeded "$cssdir")"; then
    ok "self-test: a root-relative url() the site does serve passes, and is counted"
  else
    bad "self-test: a served root-relative url() was reported missing or went uncounted"
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

  # Each end of check_landing_classes separately: a page that stopped asking for a class, and a
  # stylesheet that stopped defining one. A check that only ever sees the real pair proves nothing.
  local lc lcss
  lc=$(mktemp -d)
  lcss="$lc/theme.css"
  printf '.ark-hero{}\n.ark-section{}\n.ark-steps{}\n.ark-ways{}\n' >"$lcss"
  printf '<div class="ark-hero ark-section ark-steps ark-ways"></div>\n' >"$lc/index.html"
  if grep -q '^ok' <<<"$(check_landing_classes seeded "$lc" "$lcss")"; then
    ok "self-test: a page and stylesheet that agree on the landing classes pass"
  else
    bad "self-test: the landing-class check fails a page that does carry all four"
  fi
  printf '<div class="ark-hero ark-section ark-steps"></div>\n' >"$lc/index.html"
  if grep -q 'FAIL.*absent from the page: ark-ways' <<<"$(check_landing_classes seeded "$lc" "$lcss")"; then
    ok "self-test: a landing page that stopped asking for a class is caught"
  else
    bad "self-test: a landing page that stopped asking for a class went undetected"
  fi
  printf '.ark-hero{}\n.ark-section{}\n.ark-steps{}\n' >"$lcss"
  printf '<div class="ark-hero ark-section ark-steps ark-ways"></div>\n' >"$lc/index.html"
  if grep -q "FAIL.*absent from $lcss: ark-ways" <<<"$(check_landing_classes seeded "$lc" "$lcss")"; then
    ok "self-test: a stylesheet that dropped a landing class is caught"
  else
    bad "self-test: a stylesheet that dropped a landing class went undetected"
  fi
  rm -rf "$lc"

  # Both halves of check_dropdown_tags: the aside-qualified selector that caused the bug, and the
  # missing dropdown in the example that would have hidden it.
  local dt
  dt=$(mktemp -d)
  printf '<details class="myst-admonition myst-admonition-seealso">x</details>\n' >"$dt/index.html"
  printf ':is(aside, details).myst-admonition{border-left:2px}\n' >"$dt/ok.css"
  printf 'aside.myst-admonition{border-left:2px}\n' >"$dt/bad.css"
  if grep -q '^ok' <<<"$(check_dropdown_tags seeded "$dt" "$dt/ok.css")"; then
    ok "self-test: a stylesheet reaching both admonition tags passes"
  else
    bad "self-test: the dropdown-tag check fails a stylesheet that does reach both"
  fi
  if grep -q 'FAIL.*qualifies an admonition' <<<"$(check_dropdown_tags seeded "$dt" "$dt/bad.css")"; then
    ok "self-test: an aside-qualified admonition rule is caught"
  else
    bad "self-test: an aside-qualified admonition rule went undetected"
  fi
  printf '<aside class="myst-admonition">x</aside>\n' >"$dt/index.html"
  if grep -q 'FAIL.*no dropdown admonition' <<<"$(check_dropdown_tags seeded "$dt" "$dt/ok.css")"; then
    ok "self-test: an example carrying no dropdown admonition is caught"
  else
    bad "self-test: a missing dropdown admonition went undetected"
  fi
  rm -rf "$dt"

  # check_blue_coverage, including the boundary that makes blue-50 and blue-500 distinct classes
  local bc
  bc=$(mktemp -d)
  printf '<a class="hover:text-blue-700 bg-blue-50">x</a>\n' >"$bc/index.html"
  printf '.hover\\:text-blue-700:hover{color:red}\n.bg-blue-50{background:red}\n' >"$bc/ok.css"
  printf '.hover\\:text-blue-700:hover{color:red}\n' >"$bc/bad.css"
  printf '.hover\\:text-blue-700:hover{color:red}\n.bg-blue-500{background:red}\n' >"$bc/prefix.css"
  if grep -q '^ok' <<<"$(check_blue_coverage seeded "$bc" "$bc/ok.css")"; then
    ok "self-test: a stylesheet covering every rendered blue passes"
  else
    bad "self-test: the blue-coverage check fails a stylesheet that does cover them"
  fi
  if grep -q 'FAIL.*bg-blue-50' <<<"$(check_blue_coverage seeded "$bc" "$bc/bad.css")"; then
    ok "self-test: a blue the stylesheet never overrides is caught"
  else
    bad "self-test: an uncovered blue utility went undetected"
  fi
  if grep -q 'FAIL.*bg-blue-50' <<<"$(check_blue_coverage seeded "$bc" "$bc/prefix.css")"; then
    ok "self-test: bg-blue-500 does not stand in for bg-blue-50"
  else
    bad "self-test: a longer class name passed for a shorter one"
  fi
  printf '<a class="text-gray-500">x</a>\n' >"$bc/index.html"
  if grep -q 'FAIL.*no blue utility' <<<"$(check_blue_coverage seeded "$bc" "$bc/ok.css")"; then
    ok "self-test: pages rendering no blue at all are caught"
  else
    bad "self-test: an untested override list went undetected"
  fi
  rm -rf "$bc"

  # check_landing_button, both halves: the fill leaving the token, and the missing button behind it
  local lb
  lb=$(mktemp -d)
  printf '<a class="link button" href="/x">x</a>\n' >"$lb/index.html"
  printf 'a.button{background-color: var(--myst-color-primary)}\n' >"$lb/myst-theme.css"
  if grep -q '^ok' <<<"$(check_landing_button seeded "$lb")"; then
    ok "self-test: a button filled from the brand token passes"
  else
    bad "self-test: the button check fails a stylesheet that does use the token"
  fi
  printf 'a.button{background-color: #1d4ed8}\n' >"$lb/myst-theme.css"
  if grep -q 'FAIL.*no longer fills' <<<"$(check_landing_button seeded "$lb")"; then
    ok "self-test: a button fill hard-coded to a literal is caught"
  else
    bad "self-test: a hard-coded button fill went undetected"
  fi
  rm -f "$lb/myst-theme.css"
  if grep -q 'FAIL.*no longer fills' <<<"$(check_landing_button seeded "$lb")"; then
    ok "self-test: a site that never served the stylesheet is caught"
  else
    bad "self-test: a missing served stylesheet went undetected"
  fi
  printf 'a.button{background-color: var(--myst-color-primary)}\n' >"$lb/myst-theme.css"
  printf '<p>no button here</p>\n' >"$lb/index.html"
  if grep -q 'FAIL.*renders no button' <<<"$(check_landing_button seeded "$lb")"; then
    ok "self-test: a landing page carrying no button is caught"
  else
    bad "self-test: a missing button fixture went undetected"
  fi
  rm -rf "$lb"

  # The two checks three call sites now share, including the looser match the landing copy had
  local sv
  sv=$(mktemp -d)
  mkdir -p "$sv/build"
  if grep -q 'FAIL.*carries no palette' <<<"$(check_theme_css_served seeded "$sv")"; then
    ok "self-test: a site serving no stylesheet is caught"
  else
    bad "self-test: a missing stylesheet went undetected"
  fi
  printf '.ark-blue{color:red}%*s\n' 1200 '' >"$sv/myst-theme.css"
  if grep -q 'FAIL.*carries no palette' <<<"$(check_theme_css_served seeded "$sv")"; then
    ok "self-test: a class named ark-blue does not pass for the palette"
  else
    bad "self-test: a stylesheet carrying no --ark-blue custom property passed"
  fi
  # The regression this check carried until 2026-09-19: a stale hash under build/ answering for the
  # served file. It must not, whatever palette it holds.
  printf ':root{--ark-blue:#123}%*s\n' 1200 '' >"$sv/build/theme-abc.css"
  if grep -q 'FAIL.*carries no palette' <<<"$(check_theme_css_served seeded "$sv")"; then
    ok "self-test: a stale hashed stylesheet does not answer for the served one"
  else
    bad "self-test: a stale build/theme-*.css passed for the served stylesheet"
  fi
  # The three above all assert a failure, which an unconditionally failing check would satisfy.
  # This one holds the stale hash in place and fixes only the served file, so it fails if the read
  # moved anywhere else, and passes only on the file the page links.
  printf ':root{--ark-blue:#0a7}%*s\n' 1200 '' >"$sv/myst-theme.css"
  if grep -q 'ok.*serves theme.css' <<<"$(check_theme_css_served seeded "$sv")"; then
    ok "self-test: a served stylesheet carrying the palette passes beside a stale hash"
  else
    bad "self-test: a valid served stylesheet was rejected, so the check cannot pass at all"
  fi
  if grep -q 'FAIL.*fewer than four' <<<"$(check_faces_served seeded "$sv")"; then
    ok "self-test: a site serving no faces is caught"
  else
    bad "self-test: a missing set of faces went undetected"
  fi
  rm -rf "$sv"

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
  # A build that warned about nothing at all, which is the case the counting used to get wrong.
  # Seeded with real progress output, never an empty file: a build that writes nothing is broken,
  # and the guard below now says so rather than counting zero warnings on it.
  printf '📖 Built econark.md in 412 ms.\n🖨 Exported paper.pdf in 1.2 s.\n' >"$log"
  out=$(check_warnings seeded "$log")
  if grep -q 'ok.*(0 from imported packages)' <<<"$out"; then
    ok "self-test: a build with no warnings passes and counts none"
  else
    bad "self-test: a build with no warnings was miscounted: $out"
  fi
  # An empty log is what a build that died before writing leaves, and it reads as a clean build to
  # a bare grep. This is the guard that stops a dead build from going green.
  : >"$log"
  if grep -q 'FAIL.*proved nothing' <<<"$(check_warnings seeded "$log")" &&
    grep -q 'FAIL.*proved nothing' <<<"$(check_myst_errors seeded "$log")"; then
    ok "self-test: an empty build log is caught by both log checks"
  else
    bad "self-test: an empty build log passed as a clean build"
  fi
  printf '\342\233\224 errored: dropped footnote\ntruncated: \342\233\n' >"$log"
  if grep -q 'FAIL.*reported 1 errors' <<<"$(check_myst_errors seeded "$log")"; then
    ok "self-test: an error line is still read out of a log holding invalid UTF-8"
  else
    bad "self-test: invalid UTF-8 in the log hid a MyST error from the check"
  fi
  rm -f "$log"

  # A word in the table has no rule beside it, so the colour check must report one missing
  out=$(check_rule seeded "$PAPER" 'Discount' "$ARK_BLUE")
  if grep -q 'FAIL.*off palette' <<<"$out"; then
    ok "self-test: a missing rule is caught"
  else
    bad "self-test: a missing rule went undetected"
  fi

  # A word in the body carries the body's ink, so asking for the blue must report it unbranded
  out=$(check_ink seeded "$PAPER" 'Discount' "$ARK_BLUE")
  if grep -q 'FAIL.*unbranded' <<<"$out"; then
    ok "self-test: an unbranded word is caught"
  else
    bad "self-test: an unbranded word went undetected"
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

  # The banner that matters here is the one that is present and carries the palette, since that is
  # what every other banner check accepts. Only the ratio is wrong, which is the regression a
  # regenerated file could reintroduce without changing a colour or a coordinate.
  local ratiodir
  ratiodir=$(mktemp -d)
  sed 's/ preserveAspectRatio="none"//' "$ROOT/banner.svg" >"$ratiodir/banner-seeded.svg"
  out=$(check_site seeded "$ratiodir")
  if grep -q 'FAIL.*letterbox rather than fill' <<<"$out"; then
    ok "self-test: a banner that preserves its ratio is caught"
  else
    bad "self-test: a banner that preserves its ratio went undetected"
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

  # A theme that renamed the class would still serve the stylesheet, so this check must be exact
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
  # $PAPER is tracked and outside both cleaned directories, and myst exits 0 when typst writes
  # nothing. Removing it first makes a dead build read as absent rather than as last run's file,
  # which every check below would pass against. MINIMAL and TALL get this from examples/_build.
  (cd "$ROOT" && rm -rf _build examples/_build && rm -f "$PAPER" && myst build --typst) >"$buildlog" 2>&1
  check_warnings build "$buildlog"
  check_myst_errors build "$buildlog"
  rm -f "$buildlog"
  check_pdf paper "$PAPER" "${ANCHORS[@]}"
  check_pdf minimal "$MINIMAL" 'Minimal Example'
  check_pdf tall-table "$TALL" 'Case 35' 'Text after the table'
  check_breaks tall-table "$TALL" 'Case 1 A description' 'Case 35 A description'
  check_same_page tall-table "$TALL" 'Every case, one row each.' 'Case 1 A description'
  # The ten admonition kinds take four colours, so the example carries one of each and each is read
  # off the page. A kind whose rule went the wrong colour is invisible to every other check here.
  check_rule paper "$PAPER" 'Admonitions' "$ARK_BLUE"
  check_rule paper "$PAPER" 'Green' '#38B449'
  check_rule paper "$PAPER" 'Orange' '#FBAF3F'
  check_rule paper "$PAPER" 'Pink' '#ED2A7B'
  # Three elements MyST styles for itself, each branded through its own seam: a show rule for the
  # definition term, a wrapped subpar.grid for the panel label, and a left rule for the quotation
  check_ink paper "$PAPER" 'Perfect' "$ARK_BLUE"
  check_ink paper "$PAPER" '(a)' "$ARK_BLUE"
  check_rule paper "$PAPER" 'Prudence' '#A4A2A9'
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
  check_no_aliases docs "$ROOT/myst.yml" "$ROOT/landing/myst.yml" "$ROOT"/examples/*.md
  check_italic_kinds docs "$ROOT/econark.typ"
  check_rail_overflow rail
  (cd "$ROOT" && myst build --html) >/dev/null 2>&1
  primary="site ($(awk '/^  template:/ { print $2; exit }' "$ROOT/myst.yml"))"
  check_site "$primary" "$ROOT/_build/html"
  check_blue_coverage "$primary" "$ROOT/_build/html" "$ROOT/theme.css"
  check_dropdown_tags "$primary" "$ROOT/_build/html" "$ROOT/theme.css"
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
  check_dropdown_tags "site ($othername)" "$other/_build/html" "$ROOT/theme.css"
  check_blue_coverage "site ($othername)" "$other/_build/html" "$ROOT/theme.css"
  rm -rf "$other"
  # The landing page carries no paper, so check_site's banner, equation and download checks do not
  # apply to it. What it shares with the two demos is the stylesheet, the faces and the palette.
  (cd "$ROOT/landing" && myst build --html) >/dev/null 2>&1
  landdir="$ROOT/landing/_build/html"
  check_landing landing "$landdir"
  check_landing_button landing "$landdir"
  check_blue_coverage landing "$landdir" "$ROOT/theme.css"
  check_landing_classes landing "$landdir" "$ROOT/theme.css"
  check_css_urls landing "$landdir"
  check_faces_served landing "$landdir"
  check_theme_css_served landing "$landdir"
fi

exit $fail
