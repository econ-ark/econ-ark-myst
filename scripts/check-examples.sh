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
# Sampling the logo curves costs about seventeen seconds an asset, and the self-test runs the brand
# check four times over seeded copies. The generator reads one tracked input, so its pair of svgs is
# the same every call: built once here and compared against, the way the rasters above are kept.
BRAND_CACHE=$(mktemp -d)
trap 'rm -rf "$RASTER_CACHE" "$BRAND_CACHE"' EXIT

raster_page() {
  local pdf=$1 page=$2 key png
  key=$(stat -c '%s-%Y' "$pdf" 2>/dev/null)-$(printf '%s' "$pdf" | md5sum | cut -c1-8)-$page
  png="$RASTER_CACHE/$key.png"
  [ -f "$png" ] || pdftoppm -png -r 150 -f "$page" -l "$page" -singlefile "$pdf" "${png%.png}" 2>/dev/null
  printf '%s\n' "$png"
}

fail=0
# Pixels differing between two images, in AE_COUNT, with what compare said in AE_RAW. compare prints
# its own failures on stdout in place of a count, and a count read from one of those is empty rather
# than a number, which every caller would otherwise read as a clean match. Non-zero exit says so.
ae_pixels() {
  AE_RAW=$(compare -metric AE "$1" "$2" null: 2>&1)
  AE_COUNT=${AE_RAW%%[!0-9]*}
  [ -n "$AE_COUNT" ]
}

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
  local info
  check_text "$name" "$(pdftotext "$pdf" - 2>/dev/null)" "$@"
  # A file that is not a PDF at all clears the size test above and gives pdfinfo nothing, which the
  # bare grep read as the absence of a timestamp. check_text fails beside it, so the run still goes
  # red, but this line was printing ok about a file it had not read.
  if ! info=$(pdfinfo "$pdf" 2>/dev/null); then
    bad "$name: $pdf is not a readable PDF, so the timestamp check proved nothing"
  elif grep -q '^CreationDate' <<<"$info"; then
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
  local name=$1 hits f missing=""
  shift
  # An unmatched examples/*.md reaches grep as the literal glob: grep exits 2, the output is empty,
  # and the ok branch below reported that the examples name everything correctly. Reorganising
  # examples/ is all it took, so the paths are checked before they are read.
  for f in "$@"; do [ -f "$f" ] || missing="$missing $f"; done
  if [ "$#" -eq 0 ] || [ -n "$missing" ]; then
    bad "$name: no file at:${missing:- (no paths given)}, so the alias check read nothing"
    return
  fi
  hits=$(grep -nE '"(ack|acknowledgement|acknowledgements|acknowledgment|availability|dataAvailability|data-availability|quote|plain_language_summary|plain-language-summary|plainLanguageSummary|lay_summary|lay-summary|keyPoints|key_points|key-points)"|^[[:space:]]*(author|reviewer|editor|contributor|affiliation|export|download|part|identifier|socials|image):' "$@")
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
  local name=$1 fresh=$2 committed=$3 scratch pages p total=0
  # Every comparison below reports a match on two absent files: they extract the same empty text,
  # cmp calls two empty ones identical, and a page walk over no pages counts no differing pixels.
  # A git show that wrote nothing is how $committed arrives empty.
  if [ ! -s "$fresh" ] || [ ! -s "$committed" ]; then
    bad "$name: $fresh or $committed is missing or empty, so the tracked PDF went unchecked"
    return
  fi
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
  # old-01.png. An unparseable count would abort the arithmetic and, with it, every check after
  # this one, so ae_pixels reports that rather than letting it through as a zero.
  for ((p = 1; p <= ${pages:-0}; p++)); do
    if ! ae_pixels \
      "$(printf '%s/old-%0*d.png' "$scratch" "${#pages}" "$p")" \
      "$(printf '%s/new-%0*d.png' "$scratch" "${#pages}" "$p")"; then
      rm -rf "$scratch"
      bad "$name: page $p of the tracked PDF could not be compared, so it is unchecked: $AE_RAW"
      return
    fi
    total=$((total + AE_COUNT))
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

# No build step runs scripts/gen-banner.py, so an edit to it or to scripts/curves-crop.svg leaves
# banner.svg, favicon.svg and the favicon.png rasterised from it standing, with every other check
# here still passing. The svgs compare as bytes; the png as pixels, which every rasteriser agrees on.

# Fills BRAND_CACHE with the svgs the tracked curves produce, on the first call that needs them.
brand_reference() {
  [ -s "$BRAND_CACHE/banner.svg" ] && [ -s "$BRAND_CACHE/favicon.svg" ] && return 0
  # gen-banner.py declares its own dependencies inline, so uv resolves them and this names none
  command -v uv >/dev/null 2>&1 || return 1
  (cd "$ROOT" && uv run --no-project scripts/gen-banner.py scripts/curves-crop.svg \
    "$BRAND_CACHE/") >/dev/null 2>&1 || return 1
  [ -s "$BRAND_CACHE/banner.svg" ] && [ -s "$BRAND_CACHE/favicon.svg" ]
}

check_brand() {
  local name=$1 dir=$2 scratch asset comparable
  if ! brand_reference; then
    bad "$name: gen-banner.py did not run, so the generated assets went unchecked"
    return
  fi
  scratch=$(mktemp -d)
  for asset in banner favicon; do
    if cmp -s "$dir/$asset.svg" "$BRAND_CACHE/$asset.svg"; then
      ok "$name: the tracked $asset.svg is what the curves and the generator produce"
    else
      bad "$name: $asset.svg differs from a fresh run of gen-banner.py; commit the regenerated file"
    fi
  done
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert "$dir/favicon.svg" -o "$scratch/favicon.png" 2>/dev/null
  elif command -v inkscape >/dev/null 2>&1; then
    inkscape "$dir/favicon.svg" --export-type=png \
      --export-filename="$scratch/favicon.png" >/dev/null 2>&1
  else
    bad "$name: no rsvg-convert or inkscape, so favicon.png went unchecked against its svg"
    rm -rf "$scratch"
    return
  fi
  if [ ! -s "$scratch/favicon.png" ]; then
    bad "$name: rasterising favicon.svg wrote nothing, so favicon.png went unchecked"
    rm -rf "$scratch"
    return
  fi
  # Two images of different sizes reach ae_pixels as an unparseable count rather than a difference
  ae_pixels "$dir/favicon.png" "$scratch/favicon.png"
  comparable=$?
  rm -rf "$scratch"
  if [ "$comparable" -ne 0 ]; then
    bad "$name: favicon.png could not be compared with its svg, so it is unchecked: $AE_RAW"
  elif [ "$AE_COUNT" -eq 0 ]; then
    ok "$name: the tracked favicon.png renders identically to favicon.svg"
  else
    bad "$name: favicon.png differs from favicon.svg by $AE_COUNT pixels; re-export it"
  fi
}

# Nothing in a build here reads template.yml's files: list, so a module this repository imports but
# never lists builds clean from the working tree and fails only in a consumer's checkout, where MyST
# copies what the list names and nothing else. This walks the imports out from the entry instead.
check_template_files() {
  local name=$1 root=$2 listed dep abs f missing=0 extra
  local -a queue=(template.typ)
  local seen="" needed=""
  listed=$(awk '/^files:/ { on = 1; next } on && /^[a-z]/ { exit } on && /^  - / { print $2 }' \
    "$root/template.yml")
  if [ -z "$listed" ]; then
    bad "$name: found no files: list in template.yml, so this check proved nothing"
    return
  fi
  while [ ${#queue[@]} -gt 0 ]; do
    f=${queue[0]}
    queue=("${queue[@]:1}")
    case " $seen " in *" $f "*) continue ;; esac
    seen="$seen $f"
    needed="$needed$f"$'\n'
    while IFS= read -r dep; do
      [ -n "$dep" ] || continue
      # Each path is written relative to the file that names it, which is how it resolves in the
      # build directory too, so -m resolves it back to a repository-relative name here
      abs=$(realpath -m --relative-to="$root" "$root/$(dirname "$f")/$dep")
      needed="$needed$abs"$'\n'
      case "$abs" in *.typ) queue+=("$abs") ;; esac
    done < <(rg -o '#import "([^@"]+)"|image\("([^"]+)"\)' -r '$1$2' "$root/$f" 2>/dev/null)
  done
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    grep -qxF "$dep" <<<"$listed" || { bad "$name: template.yml does not list $dep, which the template imports"; missing=1; }
  done < <(sort -u <<<"$needed")
  extra=$(comm -23 <(sort -u <<<"$listed") <(sort -u <<<"$needed") | tr '\n' ' ')
  if [ "$missing" -eq 0 ] && [ -n "${extra// /}" ]; then
    bad "$name: template.yml lists what the template never reaches: $extra"
  elif [ "$missing" -eq 0 ]; then
    ok "$name: template.yml lists every file the template imports ($(sort -u <<<"$needed" | grep -c .))"
  fi
}

# grep exits 2 on a file that is not there, which every caller reads as no match and so as good
# news. The checks below take a SERVED stylesheet, which a build that rendered its pages can still
# fail to copy, so each one asks before reading.
require_file() {
  local name=$1 path=$2 what=$3
  [ -s "$path" ] && return 0
  bad "$name: $path is missing or empty, so $what went unchecked"
  return 1
}

# A class is styled only when its own block declares something and its name ends where the selector
# does. `.ark-hero` matched a stylesheet that had renamed it `.ark-hero-image`, `.ark-section { }`
# matched one declaring nothing, and a bare grep matched a name left in a comment.
css_declares() {
  local css=$1 cls=$2
  CLS=$cls perl -0777 -ne 'my $c = $ENV{CLS};
    s{/\*.*?\*/}{}gs;
    while (/([^{}]*)\{([^{}]*)\}/g) {
      my ($sel, $body) = ($1, $2);
      next unless $body =~ /[a-z-]+\s*:\s*[^;\s]/;
      exit 0 if $sel =~ /\.\Q$c\E(?![\w-])/;
    }
    exit 1' "$css"
}

# The page carries a JSON copy of its own config, which repeats every class name, so a class the
# markup stopped writing is still in the file. Drop the scripts, then match the whole token inside
# a class attribute rather than anywhere on the line.
page_uses_class() {
  local html=$1 cls=$2
  CLS=$cls perl -0777 -ne 'my $c = $ENV{CLS};
    s{<script\b.*?</script>}{}gs;
    exit !/class="([^"]* )?\Q$c\E( [^"]*)?"/' "$html" 2>/dev/null
}

# A leading slash means the site root, not the stylesheet's directory. Skipping that branch left
# --ark-hero-image: url("/banner.svg") unchecked on a landing that never served the file, so both
# readers of a url() resolve it here rather than each keeping a copy of the rule.
resolve_css_url() {
  local dir=$1 sheet=$2 url=$3 target
  case "$url" in
    /*) target="$dir/${url#/}" ;;
    *) target="$(dirname "$sheet")/$url" ;;
  esac
  printf '%s\n' "${target%%[?#]*}"
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
      target=$(resolve_css_url "$dir" "$sheet" "$url")
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
  require_file "$name" "$css" "the landing classes" || return
  for cls in ark-hero ark-section ark-steps ark-ways; do
    page_uses_class "$dir/index.html" "$cls" || missing_html="$missing_html $cls"
    css_declares "$css" "$cls" || missing_css="$missing_css $cls"
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
  require_file "$name" "$css" "the admonition tag split" || return
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
  require_file "$name" "$css" "the blue override list" || return
  # A selector counts only when its block declares something: .text-blue-600 { } matched the old
  # read of selector strings alone and painted nothing. Pairing each selector list with its body
  # here is also what lets a stylesheet escape its colons, which the sed then strips off.
  overridden=$(perl -0777 -ne 's{/\*.*?\*/}{}gs;
    while (/([^{}]*)\{([^{}]*)\}/g) {
      my ($sel, $body) = ($1, $2);
      next unless $body =~ /[a-z-]+\s*:\s*[^;\s]/;
      while ($sel =~ /\.([a-z0-9\\:\/-]*blue-[0-9]+(?:\\\/[0-9]+)?)/g) {
        (my $c = $1) =~ s/\\//g;
        print "$c\n";
      }
    }' "$css" | sort -u)
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
  # Split on the block wrapper and require a button in a block that is not the hero: the old guard
  # took any class holding the letters, which the two hero buttons and the nav's own
  # myst-top-nav-menu-button each satisfied. The page's JSON blob repeats every class, so it goes.
  if ! perl -0777 -ne '
      s{<script\b.*?</script>}{}gs;
      for my $block (split /myst-landing-block/) {
        next if $block =~ /ark-hero/;
        $found = 1 if $block =~ /class="([^"]* )?button( [^"]*)?"/;
      }
      exit !$found;
    ' "$dir/index.html" 2>/dev/null; then
    bad "$name: the landing page renders no button outside the hero, so the fill rule goes untested"
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

# theme.css carries no @layer and every override in it lands at the specificity it is overriding,
# so each one wins on source order alone. Move the injection point above the theme's own bundle and
# the whole palette goes inert with no rule here failing.
check_css_last() {
  local name=$1 dir=$2 last
  last=$(grep -oE '<link[^>]*rel="stylesheet"[^>]*>' "$dir/index.html" 2>/dev/null |
    grep -oE 'href="[^"]*"' | tail -1)
  if [ "$last" = 'href="/myst-theme.css"' ]; then
    ok "$name: /myst-theme.css is the last stylesheet the page links"
  else
    bad "$name: the last stylesheet the page links is ${last:-none}, so theme.css no longer wins ties on order"
  fi
}

# The bundled theme predates --myst-color-* (#843), so the stylesheet has to declare every one of
# those it reads. Gut its :root block and the button fill resolves to nothing: the theme's white
# label lands on the page with no fill under it, which nothing else here reads.
check_tokens_defined() {
  local name=$1 sheet=$2 used declared missing
  used=$(grep -oE 'var\(--myst-color-[a-z-]+' "$sheet" 2>/dev/null | sed 's/^var(//' | sort -u)
  if [ -z "$used" ]; then
    bad "$name: $sheet reads no --myst-color- token, so this check proved nothing"
    return
  fi
  declared=$(grep -oE -- '--myst-color-[a-z-]+[[:space:]]*:' "$sheet" | sed 's/[[:space:]]*:$//' | sort -u)
  missing=$(comm -23 <(echo "$used") <(echo "$declared") | tr '\n' ' ')
  if [ -n "${missing// /}" ]; then
    bad "$name: $sheet reads tokens nothing in it declares: $missing"
  else
    ok "$name: every --myst-color- token the stylesheet reads is declared in it ($(wc -l <<<"$used"))"
  fi
}

# The faces are built rather than tracked, so a site can be published complete in every other way
# and still fall back to the system sans, which no page of it would report
check_faces_served() {
  local name=$1 dir=$2 sheet="$2/myst-theme.css" url n=0
  # Only a face the served sheet names, at a path the site serves, reaches a reader. Counting woff2
  # anywhere under the build counted the template's own cache copies too, so a landing serving none
  # of them to its pages still cleared four.
  while IFS= read -r url; do
    [ -f "$(resolve_css_url "$dir" "$sheet" "$url")" ] && n=$((n + 1))
  done < <(sed -nE "s@.*url\((['\"]?)([^'\")]*FiraSans-[^'\")]*\.woff2)\1\).*@\2@p" "$sheet" 2>/dev/null |
    sort -u)
  if [ "$n" -ge 4 ]; then
    ok "$name: the served stylesheet names $n Fira Sans faces the site serves"
  else
    bad "$name: $sheet names only $n served FiraSans woff2, so readers get the system sans"
  fi
}

# The plugin is the only thing putting MathML on the page. Were it to stop loading the build would
# still succeed and every equation would come back in KaTeX's Computer Modern, which is legible
# enough that nothing else here would notice. Both sites carry equations, so both are read.
check_mathml() {
  local name=$1 dir=$2 html
  html=$(cat "$dir"/index.html "$dir"/*/index.html 2>/dev/null)
  if grep -q '<math' <<<"$html" && ! grep -q 'class="katex-html"' <<<"$html"; then
    ok "$name: the equations reach the page as MathML, which is what can take Fira Math"
  else
    bad "$name: no <math> under $dir, or KaTeX markup still present, so equations are not in Fira Math"
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
  check_mathml "$name" "$dir"
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

# One case per line: run the check, require its output to match, and let the label say what that
# proves. A miss now prints what the check said instead, which the four-line form it replaces
# threw away. Cases needing several patterns at once stay written out below.
expect() {
  local want=$1 label=$2 out
  shift 2
  out=$("$@")
  if grep -qE -- "$want" <<<"$out"; then
    ok "self-test: $label"
  else
    bad "self-test: $label; the check said: ${out//$'\n'/ | }"
  fi
}

self_test() {
  local good seeded out fixture
  # $TALL seeds four of the tests below, three of which assert a FAILURE, so an absent fixture used
  # to satisfy the very tests meant to prove those checks have power. Both fixtures are required.
  for fixture in "$PAPER" "$TALL"; do
    [ -s "$fixture" ] || { echo "self-test needs a built $fixture"; exit 2; }
  done
  good=$(pdftotext "$PAPER" - 2>/dev/null)
  [ -n "$good" ] || { echo "self-test needs text in $PAPER"; exit 2; }

  # Every case below runs through expect, so an expect that stopped comparing would pass all of
  # them in silence. These two run it against output whose verdict is known, one each way.
  expect '^ok$' 'expect reports output that matches' echo ok
  if grep -q 'FAIL' <<<"$(expect 'cannot-match-this' 'unreachable' echo ok)"; then
    ok "self-test: expect reports output that does not match"
  else
    bad "self-test: expect passed a miss, so every case below proves nothing"
  fi

  seeded="$good"$'\n''See Section ??.'
  expect 'FAIL.*unresolved' 'a literal ?? is caught' check_text seeded "$seeded" "${ANCHORS[@]}"
  seeded="$good"$'\n'"Table 1${PRIME}s parameters."
  expect 'FAIL.*prime' 'a prime after a digit is caught' check_text seeded "$seeded" "${ANCHORS[@]}"
  seeded=${good//Proposition 1 (Concavity)/}
  expect "FAIL.*missing 'Proposition 1" 'a missing anchor is caught' \
    check_text seeded "$seeded" "${ANCHORS[@]}"

  # The calibration table fits one page and the figure caption sits in the text column, so the
  # full example is itself the seed for these two
  expect 'FAIL.*did not break' 'a table that stays on one page is caught' \
    check_breaks seeded "$PAPER" 'Discount factor' 'Relative risk aversion'
  expect 'FAIL.*not widened' 'a figure left at text width is caught' \
    check_left_of seeded "$PAPER" 'Baseline' 100
  expect 'FAIL.*not written' 'a missing PDF is caught' \
    check_pdf seeded "$EXAMPLES/exports/does-not-exist.pdf"
  # The tall table's caption and its last row are pages apart, so they must read as orphaned
  expect 'FAIL.*orphaned' 'an orphaned caption is caught' \
    check_same_page seeded "$TALL" 'Every case, one row each.' 'Case 35 A description'

  # Typst stamps a creation date unless the template clears it, so a plain compile seeds the defect
  local scratch
  scratch=$(mktemp -d)
  printf 'A page.\n' >"$scratch/stamped.typ"
  if typst compile "$scratch/stamped.typ" "$scratch/stamped.pdf" >/dev/null 2>&1; then
    expect 'FAIL.*creation timestamp' 'a creation timestamp is caught' \
      check_pdf seeded "$scratch/stamped.pdf" 'A page.'
  else
    bad "self-test: could not compile a timestamped PDF to seed the check"
  fi
  printf 'not a pdf at all\n' >"$scratch/notapdf.pdf"
  expect 'FAIL.*not a readable PDF' 'a file that is not a PDF is caught by the timestamp check too' \
    check_pdf seeded "$scratch/notapdf.pdf"
  rm -rf "$scratch"

  # Two different PDFs stand in for a tracked file left behind by its sources. The empty pair below
  # is the no-evidence case: both extract the same empty text and cmp calls them identical.
  expect 'FAIL.*text differs' 'a stale tracked PDF is caught' check_tracked seeded "$PAPER" "$TALL"
  local empties
  empties=$(mktemp -d)
  : >"$empties/a.pdf"
  : >"$empties/b.pdf"
  expect 'FAIL.*went unchecked' 'two empty PDFs do not pass for a tracked file matching its sources' \
    check_tracked seeded "$empties/a.pdf" "$empties/b.pdf"
  expect 'FAIL.*went unchecked' 'two absent PDFs do not pass for a tracked file matching its sources' \
    check_tracked seeded "$empties/gone.pdf" "$empties/also-gone.pdf"
  rm -rf "$empties"

  # The same words at another weight: the text check reads them as equal, so only the pages differ
  local weights
  weights=$(mktemp -d)
  printf '#set text(font: "Fira Sans", weight: 500)\nSame words either way.\n' >"$weights/light.typ"
  printf '#set text(font: "Fira Sans", weight: 700)\nSame words either way.\n' >"$weights/heavy.typ"
  if typst compile "$weights/light.typ" "$weights/light.pdf" >/dev/null 2>&1 &&
    typst compile "$weights/heavy.typ" "$weights/heavy.pdf" >/dev/null 2>&1; then
    expect 'FAIL.*renders differently' 'a PDF whose text matches but whose pages differ is caught' \
      check_tracked seeded "$weights/heavy.pdf" "$weights/light.pdf"
  else
    bad "self-test: could not compile the two weights that seed the render check"
  fi
  rm -rf "$weights"

  # The exact shape of the bug this repository shipped: a stylesheet naming a font beside it that
  # the site never serves. Temml's sheet does this, which is why fonts.sh now fetches both.
  local cssdir
  cssdir=$(mktemp -d)
  printf '@font-face { src: url("Temml.woff2") format("woff2"); }\n' >"$cssdir/myst-theme.css"
  expect 'FAIL.*does not serve' 'a stylesheet asking for a file the site lacks is caught' \
    check_css_urls seeded "$cssdir"
  : >"$cssdir/Temml.woff2"
  expect 'ok.*resolves' 'a stylesheet whose files are all served passes' \
    check_css_urls seeded "$cssdir"
  # The root-relative branch, which this check used to skip outright
  printf '@font-face { src: url("Temml.woff2") format("woff2"); }\n.h{background:url("/banner.svg")}\n' >"$cssdir/myst-theme.css"
  expect 'FAIL.*asks for /banner.svg' 'a root-relative url() the site lacks is caught' \
    check_css_urls seeded "$cssdir"
  : >"$cssdir/banner.svg"
  expect 'ok.*resolves \(2 references\)' 'a root-relative url() the site serves passes, and is counted' \
    check_css_urls seeded "$cssdir"
  rm -rf "$cssdir"

  expect "FAIL.*package.json 'none'" 'Temml pins that disagree are caught' \
    check_temml_pin seeded "$ROOT/scripts/fonts.sh" /dev/null

  # A landing page built under a theme that claims none of the block kinds, which is what
  # article-theme does: the blocks come out as ordinary headings with no wrapper at all
  local land
  land=$(mktemp -d)
  printf '<div class="myst-landing-block">one</div>\n<p>Invalid block</p>\n' >"$land/index.html"
  expect 'FAIL.*landing blocks under' 'a landing page whose blocks the theme rejected is caught' \
    check_landing seeded "$land"
  rm -rf "$land"

  # Both predicates are shared, so the shapes they reject are seeded once here rather than once per
  # caller. Each is a way a rule goes inert while its name stays in the file, and on the page side
  # a class the markup dropped that the JSON config blob still carries.
  local pred
  pred=$(mktemp -d)
  # expect calls these through "$@", which shellcheck's reachability pass cannot follow
  # shellcheck disable=SC2317,SC2329
  declares_says() { css_declares "$1" "$2" && echo yes || echo no; }
  # shellcheck disable=SC2317,SC2329
  uses_says() { page_uses_class "$1" "$2" && echo yes || echo no; }
  printf '.ark-hero-image{color:red}\n.ark-section{ }\n/* .ark-ways */\n.ark-steps{color:red}\n' >"$pred/css"
  printf '<div class="ark-steps"></div><script>{"class":"ark-hero"}</script>\n' >"$pred/index.html"
  expect '^no$' 'a renamed class does not answer for the one it replaced' \
    declares_says "$pred/css" ark-hero
  expect '^no$' 'a rule that declares nothing does not count as styled' \
    declares_says "$pred/css" ark-section
  expect '^no$' 'a class left only in a comment does not count as styled' \
    declares_says "$pred/css" ark-ways
  expect '^yes$' 'a rule that does declare a property counts as styled' \
    declares_says "$pred/css" ark-steps
  expect '^no$' "a class only in the page's JSON blob is not on the page" \
    uses_says "$pred/index.html" ark-hero
  expect '^yes$' 'a class the markup writes is on the page' uses_says "$pred/index.html" ark-steps
  rm -rf "$pred"

  # That both predicates are wired into the check, one end each, plus the pair agreeing
  local lc lcss
  lc=$(mktemp -d)
  lcss="$lc/theme.css"
  printf '.ark-hero{color:red}\n.ark-section{color:red}\n.ark-steps{color:red}\n.ark-ways{color:red}\n' >"$lcss"
  printf '<div class="ark-hero ark-section ark-steps ark-ways"></div>\n' >"$lc/index.html"
  expect '^ok' 'a page and stylesheet that agree on the landing classes pass' \
    check_landing_classes seeded "$lc" "$lcss"
  printf '<div class="ark-hero ark-section ark-steps"></div>\n' >"$lc/index.html"
  expect 'FAIL.*absent from the page: ark-ways' 'a landing page that stopped asking for a class is caught' \
    check_landing_classes seeded "$lc" "$lcss"
  printf '.ark-hero{color:red}\n.ark-section{color:red}\n.ark-steps{color:red}\n' >"$lcss"
  printf '<div class="ark-hero ark-section ark-steps ark-ways"></div>\n' >"$lc/index.html"
  expect "FAIL.*absent from $lcss: ark-ways" 'a stylesheet that dropped a landing class is caught' \
    check_landing_classes seeded "$lc" "$lcss"
  rm -rf "$lc"

  # Both halves of check_dropdown_tags: the aside-qualified selector that caused the bug, and the
  # missing dropdown in the example that would have hidden it.
  local dt
  dt=$(mktemp -d)
  printf '<details class="myst-admonition myst-admonition-seealso">x</details>\n' >"$dt/index.html"
  printf ':is(aside, details).myst-admonition{border-left:2px}\n' >"$dt/ok.css"
  printf 'aside.myst-admonition{border-left:2px}\n' >"$dt/bad.css"
  expect '^ok' 'a stylesheet reaching both admonition tags passes' \
    check_dropdown_tags seeded "$dt" "$dt/ok.css"
  expect 'FAIL.*qualifies an admonition' 'an aside-qualified admonition rule is caught' \
    check_dropdown_tags seeded "$dt" "$dt/bad.css"
  printf '<aside class="myst-admonition">x</aside>\n' >"$dt/index.html"
  expect 'FAIL.*no dropdown admonition' 'an example carrying no dropdown admonition is caught' \
    check_dropdown_tags seeded "$dt" "$dt/ok.css"
  rm -rf "$dt"

  # check_blue_coverage, including the boundary that makes blue-50 and blue-500 distinct classes.
  # The empty rule and the commented-out one are the predicate's, seeded above.
  local bc
  bc=$(mktemp -d)
  printf '<a class="hover:text-blue-700 bg-blue-50">x</a>\n' >"$bc/index.html"
  printf '.hover\\:text-blue-700:hover{color:red}\n.bg-blue-50{background:red}\n' >"$bc/ok.css"
  printf '.hover\\:text-blue-700:hover{color:red}\n' >"$bc/bad.css"
  printf '.hover\\:text-blue-700:hover{color:red}\n.bg-blue-500{background:red}\n' >"$bc/prefix.css"
  expect '^ok' 'a stylesheet covering every rendered blue passes' \
    check_blue_coverage seeded "$bc" "$bc/ok.css"
  expect 'FAIL.*bg-blue-50' 'a blue the stylesheet never overrides is caught' \
    check_blue_coverage seeded "$bc" "$bc/bad.css"
  expect 'FAIL.*bg-blue-50' 'bg-blue-500 does not stand in for bg-blue-50' \
    check_blue_coverage seeded "$bc" "$bc/prefix.css"
  printf '<a class="text-gray-500">x</a>\n' >"$bc/index.html"
  expect 'FAIL.*no blue utility' 'pages rendering no blue at all are caught' \
    check_blue_coverage seeded "$bc" "$bc/ok.css"
  rm -rf "$bc"

  # check_landing_button: the fill leaving the token, and the fixture guard behind it. A hero-only
  # page and the theme's own nav control, whose class merely ends in the word, are one case each.
  local lb
  lb=$(mktemp -d)
  printf '<a class="link button" href="/x">x</a>\n' >"$lb/index.html"
  printf 'a.button{background-color: var(--myst-color-primary)}\n' >"$lb/myst-theme.css"
  expect '^ok' 'a button filled from the brand token passes' check_landing_button seeded "$lb"
  printf 'a.button{background-color: #1d4ed8}\n' >"$lb/myst-theme.css"
  expect 'FAIL.*no longer fills' 'a button fill hard-coded to a literal is caught' \
    check_landing_button seeded "$lb"
  rm -f "$lb/myst-theme.css"
  expect 'FAIL.*no longer fills' 'a site that never served the stylesheet is caught' \
    check_landing_button seeded "$lb"
  printf 'a.button{background-color: var(--myst-color-primary)}\n' >"$lb/myst-theme.css"
  printf '<div class="myst-landing-block ark-hero"><a class="link button">x</a></div>\n%s\n' \
    '<button class="myst-top-nav-menu-button flex h-10">m</button>' >"$lb/index.html"
  expect 'FAIL.*no button outside the hero' 'a hero button and a nav control are not the fixture' \
    check_landing_button seeded "$lb"
  printf '<div class="myst-landing-block ark-hero"><a class="link button">x</a></div>\n%s\n' \
    '<div class="myst-landing-block ark-section"><a class="link whitespace-nowrap button">y</a></div>' >"$lb/index.html"
  expect '^ok' 'a button in a block that is not the hero is the fixture' \
    check_landing_button seeded "$lb"
  rm -rf "$lb"

  # The two checks three call sites now share, including the looser match the landing copy had
  local sv
  sv=$(mktemp -d)
  mkdir -p "$sv/build"
  expect 'FAIL.*carries no palette' 'a site serving no stylesheet is caught' \
    check_theme_css_served seeded "$sv"
  printf '.ark-blue{color:red}%*s\n' 1200 '' >"$sv/myst-theme.css"
  expect 'FAIL.*carries no palette' 'a class named ark-blue does not pass for the palette' \
    check_theme_css_served seeded "$sv"
  # A stale hash under build/ answering for the served file, which this check did until 2026-09-19.
  # The pass below holds that hash in place, so it fails if the read moves anywhere else.
  printf ':root{--ark-blue:#123}%*s\n' 1200 '' >"$sv/build/theme-abc.css"
  expect 'FAIL.*carries no palette' 'a stale hashed stylesheet does not answer for the served one' \
    check_theme_css_served seeded "$sv"
  printf ':root{--ark-blue:#0a7}%*s\n' 1200 '' >"$sv/myst-theme.css"
  expect 'ok.*serves theme.css' 'a served stylesheet carrying the palette passes beside a stale hash' \
    check_theme_css_served seeded "$sv"

  # Faces counted three ways that must not count: none at all, four sitting in a build cache no
  # stylesheet names, and four named at a path the site does not serve.
  mkdir -p "$sv/build/cache" "$sv/fonts"
  local face
  expect 'FAIL.*names only 0' 'a site serving no faces is caught' check_faces_served seeded "$sv"
  for face in Regular Italic Medium Bold; do : >"$sv/build/cache/FiraSans-$face.woff2"; done
  expect 'FAIL.*names only 0' 'faces the served stylesheet never names do not count as served' \
    check_faces_served seeded "$sv"
  { printf ':root{--ark-blue:#0a7}\n'
    for face in Regular Italic Medium Bold; do
      printf '@font-face{src:url("fonts/FiraSans-%s.woff2") format("woff2")}\n' "$face"
    done; } >"$sv/myst-theme.css"
  expect 'FAIL.*names only 0' 'faces named at a path the site lacks do not count as served' \
    check_faces_served seeded "$sv"
  for face in Regular Italic Medium Bold; do : >"$sv/fonts/FiraSans-$face.woff2"; done
  expect 'ok.*names 4 Fira Sans faces' 'four faces named and served pass' \
    check_faces_served seeded "$sv"
  rm -rf "$sv"

  # check_css_last: theme.css beats the theme's bundle on source order alone, so the order is the
  # assertion. A page linking it anywhere but last has every override in it inert.
  local ord
  ord=$(mktemp -d)
  printf '%s\n%s\n' '<link rel="stylesheet" href="/build/_assets/app-A.css"/>' \
    '<link rel="stylesheet" href="/myst-theme.css"/>' >"$ord/index.html"
  expect 'ok.*is the last stylesheet' 'a page linking the stylesheet last passes' \
    check_css_last seeded "$ord"
  printf '%s\n%s\n' '<link rel="stylesheet" href="/myst-theme.css"/>' \
    '<link rel="stylesheet" href="/build/_assets/app-A.css"/>' >"$ord/index.html"
  expect 'FAIL.*no longer wins ties on order' "a stylesheet injected above the theme's bundle is caught" \
    check_css_last seeded "$ord"
  rm -rf "$ord"

  # check_tokens_defined: the bundled theme declares none of these, so a usage the stylesheet does
  # not also declare resolves to nothing, and the property it sets simply does not apply.
  local tok
  tok=$(mktemp)
  printf ':root{--myst-color-primary:#1f476b}\na.button{background-color:var(--myst-color-primary)}\n' >"$tok"
  expect 'ok.*is declared in it' 'a stylesheet declaring every token it reads passes' \
    check_tokens_defined seeded "$tok"
  printf 'a.button{background-color:var(--myst-color-primary)}\n' >"$tok"
  expect 'FAIL.*reads tokens nothing in it declares' 'a token read but never declared is caught' \
    check_tokens_defined seeded "$tok"
  printf 'a.button{background-color:#1f476b}\n' >"$tok"
  expect 'FAIL.*proved nothing' 'a stylesheet reading no token at all is caught' \
    check_tokens_defined seeded "$tok"
  rm -f "$tok"

  # check_no_aliases reads paths a glob produced, and an unmatched glob reaches it as its own text
  local al
  al=$(mktemp -d)
  printf 'project:\n  author: A Person\n' >"$al/aliased.yml"
  printf 'project:\n  authors:\n    - name: A Person\n' >"$al/clean.yml"
  expect 'FAIL.*so the alias check read nothing' 'a glob that matched no file is caught' \
    check_no_aliases seeded "$al"/does-not-exist-*.md
  expect 'FAIL.*aliases used' 'a MyST alias in a config is caught' \
    check_no_aliases seeded "$al/aliased.yml"
  expect '^ok' 'a config using the canonical names passes' check_no_aliases seeded "$al/clean.yml"
  rm -rf "$al"

  # The README documenting a key the config no longer carries, which is how these two drift
  local conf
  conf=$(mktemp)
  printf 'site:\n  template: book-theme\n' >"$conf"
  expect 'FAIL.*README shows' 'a README documenting a key the config lacks is caught' \
    check_documented_config seeded "$ROOT/README.md" "$conf"
  rm -f "$conf"

  # A machine that never had Fira Math installed, then a font directory holding one release twice,
  # which is what a mixed ttf and otf install looks like. Fira has no Black, so that weight stands
  # for any that resolved to a file the template lacks.
  expect 'FAIL.*does not find Fira Math' 'a missing font family is caught' \
    check_family seeded "$(printf 'Fira Sans\nFira Mono\nDejaVu Sans Mono\n')" "Fira Math"
  expect 'FAIL.*2 files offer' 'two files offering one weight is caught' check_weight_files seeded \
    "$(printf 'Fira Sans\n  |- /a/FiraSans-Medium.ttf\n      Style: Normal, Weight: 500, Stretch: 100%%\n  |- /b/FiraSans-Medium.otf\n      Style: Normal, Weight: 500, Stretch: 100%%\n')" \
    "Fira Sans" Normal 500
  expect 'FAIL.*not embedded' 'a weight that resolved to another font file is caught' \
    check_font seeded "$PAPER" FiraSans-Black

  # A log carrying a warning about a file of this template, beside the packages' own noise
  local log
  log=$(mktemp)
  printf 'warning: unknown variable\n  ┌─ econ-ark.typ:12:3\nwarning: no whitespace\n  ┌─ @preview/scienceicons:0.1.0/index.typ:2:20\n' >"$log"
  expect 'FAIL.*name files of this template' 'a build warning about this template is caught' \
    check_warnings seeded "$log"
  printf 'warning: no whitespace\n  ┌─ @preview/scienceicons:0.1.0/index.typ:2:20\n' >"$log"
  expect 'ok.*imported packages' "a package's own warnings pass" check_warnings seeded "$log"
  # Real progress output, never an empty file: a build writing nothing is broken, and the guard
  # below says so rather than counting zero warnings on it.
  printf '📖 Built econ-ark.md in 412 ms.\n🖨 Exported paper.pdf in 1.2 s.\n' >"$log"
  expect 'ok.*\(0 from imported packages\)' 'a build with no warnings passes and counts none' \
    check_warnings seeded "$log"
  # An empty log is what a build that died before writing leaves, and both log checks have to say so
  : >"$log"
  expect 'FAIL.*proved nothing' 'an empty build log is caught by the warning check' \
    check_warnings seeded "$log"
  expect 'FAIL.*proved nothing' 'an empty build log is caught by the error check' \
    check_myst_errors seeded "$log"
  printf '\342\233\224 errored: dropped footnote\ntruncated: \342\233\n' >"$log"
  expect 'FAIL.*reported 1 errors' 'an error line is still read out of a log holding invalid UTF-8' \
    check_myst_errors seeded "$log"
  rm -f "$log"

  # A word in the table carries no rule beside it, and a word in the body carries the body's ink
  expect 'FAIL.*off palette' 'a missing rule is caught' check_rule seeded "$PAPER" 'Discount' "$ARK_BLUE"
  expect 'FAIL.*unbranded' 'an unbranded word is caught' check_ink seeded "$PAPER" 'Discount' "$ARK_BLUE"

  # check_site is a composite, so its empty-directory case has to report every assertion in it.
  # One missing line here means one assertion that passes on a site serving nothing.
  local want
  out=$(check_site seeded "$(mktemp -d)")
  for want in unstyled 'no banner' 'rule is inert' 'four-colour rule is missing' \
    'vanishes at night' "MyST's own mark" 'soften the theme' 'cannot reach the PDF' \
    'system sans' 'system math font' 'Plain Language Summary again'; do
    grep -q "FAIL.*$want" <<<"$out" ||
      bad "self-test: a site serving nothing did not report '$want'"
  done
  ok "self-test: a site serving no stylesheet, banner, logo or class reports all eleven"

  # The banner present and carrying the palette, which every other banner check accepts, with only
  # the ratio wrong: the regression a regenerated file reintroduces without moving a coordinate.
  local ratiodir
  ratiodir=$(mktemp -d)
  sed 's/ preserveAspectRatio="none"//' "$ROOT/brand/banner.svg" >"$ratiodir/banner-seeded.svg"
  expect 'FAIL.*letterbox rather than fill' 'a banner that preserves its ratio is caught' \
    check_site seeded "$ratiodir"
  rm -rf "$ratiodir"

  # A bundle left behind by an edit to the plugin source, which is the way this one goes wrong
  local stale
  stale=$(mktemp)
  printf 'export default { name: "stale" };\n' >"$stale"
  expect 'FAIL.*is stale' 'a bundle that no longer matches the plugin source is caught' \
    check_bundle seeded "$stale"
  rm -f "$stale"

  # The two ways the brand assets rot: an svg left behind by an edit to the curves or the generator,
  # and a favicon.png that stopped being the raster of the svg beside it. The unseeded tree passes,
  # which is what proves the two failures below come from the seed rather than the check.
  local brand
  brand=$(mktemp -d)
  cp "$ROOT/brand/banner.svg" "$ROOT/brand/favicon.svg" "$ROOT/brand/favicon.png" "$brand/"
  expect 'ok.*renders identically to favicon.svg' 'the tracked brand assets pass unseeded' \
    check_brand seeded "$brand"
  sed 's/#1f476b/#ff0000/' "$ROOT/brand/banner.svg" >"$brand/banner.svg"
  expect 'FAIL.*banner.svg differs from a fresh run' 'a stale banner.svg is caught' \
    check_brand seeded "$brand"
  cp "$ROOT/brand/banner.svg" "$brand/banner.svg"
  convert -size 256x256 xc:red "$brand/favicon.png"
  expect 'FAIL.*favicon.png differs from favicon.svg' 'a favicon.png that is not its svg is caught' \
    check_brand seeded "$brand"
  rm -rf "$brand"

  # The two ways the manifest and the imports part: a module the template reaches that the list
  # never names, which builds here and fails in a consumer's checkout, and a name the list carries
  # that nothing imports. The unseeded copy between them shows the seeds are what fail.
  local manifestdir
  manifestdir=$(mktemp -d)
  mkdir -p "$manifestdir/ark" "$manifestdir/brand"
  cp "$ROOT/template.typ" "$ROOT/econ-ark.typ" "$manifestdir/"
  cp "$ROOT"/ark/*.typ "$manifestdir/ark/"
  cp "$ROOT/brand/logo.png" "$manifestdir/brand/"
  grep -v '^  - ark/blocks.typ$' "$ROOT/template.yml" >"$manifestdir/template.yml"
  expect 'FAIL.*does not list ark/blocks.typ' 'a module missing from template.yml is caught' \
    check_template_files seeded "$manifestdir"
  cp "$ROOT/template.yml" "$manifestdir/template.yml"
  expect 'ok.*lists every file' 'the tracked manifest passes unseeded' \
    check_template_files seeded "$manifestdir"
  sed 's|^  - brand/logo.png$|  - ark/nowhere.typ\n  - brand/logo.png|' "$ROOT/template.yml" \
    >"$manifestdir/template.yml"
  expect 'FAIL.*never reaches' 'a manifest entry nothing imports is caught' \
    check_template_files seeded "$manifestdir"
  rm -rf "$manifestdir"

  # Equations that came out of KaTeX after all, then a theme that renamed the article class while
  # still serving the stylesheet, which is why that match has to be an exact token
  local sites
  sites=$(mktemp -d)
  mkdir -p "$sites/katex" "$sites/renamed"
  printf '<article class="article"><span class="katex"><span class="katex-html">v(m)</span></span></article>\n' \
    >"$sites/katex/index.html"
  expect 'FAIL.*not in Fira Math' 'a site whose equations stayed in KaTeX is caught' \
    check_site seeded "$sites/katex"
  # The same three cases against the extracted check, which both sites now call: KaTeX markup left
  # behind, a page carrying no equation at all, and the MathML that proves the plugin ran.
  expect 'FAIL.*not in Fira Math' 'KaTeX markup is caught by the math check itself' \
    check_mathml seeded "$sites/katex"
  printf '<article class="article">no equation here</article>\n' >"$sites/katex/index.html"
  expect 'FAIL.*no <math>' 'a page carrying no equation at all is caught' \
    check_mathml seeded "$sites/katex"
  printf '<article class="article"><math><mi>v</mi></math></article>\n' >"$sites/katex/index.html"
  expect 'ok.*reach the page as MathML' 'a page whose equations are MathML passes' \
    check_mathml seeded "$sites/katex"
  printf '<article class="article-grid subgrid-gap">no article token</article>\n' >"$sites/renamed/index.html"
  cp "$ROOT/theme.css" "$sites/renamed/theme-0.css"
  cp "$ROOT/brand/banner.svg" "$sites/renamed/banner-0.svg"
  expect 'FAIL.*rule is inert' 'a theme that dropped the article class is caught' \
    check_site seeded "$sites/renamed"
  rm -rf "$sites"

  # A kind list short of amsthm's plain style, which is what a hand edit to the template leaves
  local ik
  ik=$(mktemp)
  printf '#let italicKinds = ("theorem", "lemma")\n' >"$ik"
  expect "FAIL.*not amsthm's plain style" "an italic kind list short of amsthm's plain style is caught" \
    check_italic_kinds seeded "$ik"
  printf '#let italicKinds = ("theorem", "lemma", "proposition", "corollary", "conjecture", "criterion")\n' >"$ik"
  expect '^ok' 'the amsthm plain-style kind list passes' check_italic_kinds seeded "$ik"
  rm -f "$ik"

  # A check shipped with no fixture proves nothing, which is how every silent pass here arrived.
  # This reads the text of this function, so a check named nowhere above fails the run.
  local seeded_here canary
  seeded_here=$(declare -f self_test)
  sweep_fixtures() {
    local fn
    for fn in $(declare -F | sed -n 's/^declare -f \(check_[a-z_]*\)$/\1/p'); do
      # Written exemptions, never omissions: check_swatch is exercised through check_rule and
      # check_ink, and check_rail_overflow builds its own paper against this very template, so
      # seeding a failure would take a second template declining to move the reviewers out.
      case $fn in check_swatch | check_rail_overflow) continue ;; esac
      grep -q "(^|[^a-z_])$fn([^a-z_]|$)" -E <<<"$seeded_here" ||
        bad "self-test: $fn has no fixture here, so nothing shows it can fail"
    done
  }
  sweep_fixtures
  # The sweep can quietly stop matching, which would leave it one more check reporting ok off
  # evidence it never read. The canary's name is assembled so the text above cannot seed it.
  canary=check_zz
  canary="${canary}_unseeded"
  eval "$canary() { :; }"
  if grep -q "FAIL.*$canary has no fixture" <<<"$(sweep_fixtures)"; then
    ok "self-test: the fixture sweep reports a check that nothing here seeds"
  else
    bad "self-test: the fixture sweep passed a check it was never given a fixture for"
  fi
  unset -f "$canary" sweep_fixtures
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
  check_brand brand "$ROOT/brand"
  check_template_files manifest "$ROOT"
  check_temml_pin pins "$ROOT/scripts/fonts.sh" "$ROOT/package.json"
  check_documented_config docs "$ROOT/README.md" "$ROOT/myst.yml"
  check_no_aliases docs "$ROOT/myst.yml" "$ROOT/landing/myst.yml" "$ROOT"/examples/*.md
  check_italic_kinds docs "$ROOT/ark/blocks.typ"
  check_rail_overflow rail
  (cd "$ROOT" && myst build --html) >/dev/null 2>&1
  primary="site ($(awk '/^  template:/ { print $2; exit }' "$ROOT/myst.yml"))"
  check_site "$primary" "$ROOT/_build/html"
  check_css_last "$primary" "$ROOT/_build/html"
  # The served copy rather than $ROOT/theme.css throughout: a build that failed to copy the
  # stylesheet leaves the source read passing about a site that carries none of it.
  check_tokens_defined "$primary" "$ROOT/_build/html/myst-theme.css"
  check_blue_coverage "$primary" "$ROOT/_build/html" "$ROOT/_build/html/myst-theme.css"
  check_dropdown_tags "$primary" "$ROOT/_build/html" "$ROOT/_build/html/myst-theme.css"
  # The stylesheet claims to dress either theme, so build the other one from a copy of the tree
  other=$(mktemp -d)
  # node_modules is linked rather than copied: the plugin has to resolve from the copy or its
  # equations come back as KaTeX, but copying it spends a tenth of a second on every run
  tar -c --exclude=_build --exclude=.git --exclude=./node_modules -C "$ROOT" . | tar -x -C "$other"
  ln -s "$ROOT/node_modules" "$other/node_modules"
  # sed -i exits 0 on no match, so "not article-theme" used to mean book-theme even when myst.yml
  # quoted the value or named neither, and the run then built one theme twice under the other's
  # heading. Read the value, write its counterpart, and confirm the file now carries it.
  case "$(awk '/^  template:/ { gsub(/["'\'']/, "", $2); print $2; exit }' "$other/myst.yml")" in
    article-theme) othername=book-theme ;;
    book-theme) othername=article-theme ;;
    *) othername="" ;;
  esac
  [ -n "$othername" ] && sed -i -E "s/^(  template:).*/\1 $othername/" "$other/myst.yml"
  if [ -z "$othername" ] || ! grep -qx "  template: $othername" "$other/myst.yml"; then
    bad "site (other theme): $other/myst.yml does not name the second theme, so it went unbuilt"
  else
    (cd "$other" && myst build --html) >/dev/null 2>&1
    check_site "site ($othername)" "$other/_build/html"
    check_css_last "site ($othername)" "$other/_build/html"
    check_dropdown_tags "site ($othername)" "$other/_build/html" "$other/_build/html/myst-theme.css"
    check_blue_coverage "site ($othername)" "$other/_build/html" "$other/_build/html/myst-theme.css"
  fi
  rm -rf "$other"
  # The landing page carries no paper, so check_site's banner, equation and download checks do not
  # apply to it. What it shares with the two demos is the stylesheet, the faces and the palette.
  # _build goes first: site/public keeps every theme-<hash>.css it has built and re-emits them all.
  rm -rf "$ROOT/landing/_build"
  (cd "$ROOT/landing" && myst build --html) >/dev/null 2>&1
  landdir="$ROOT/landing/_build/html"
  check_landing landing "$landdir"
  check_landing_button landing "$landdir"
  # The landing loads the plugin too, and now carries the equations that prove it ran
  check_mathml landing "$landdir"
  check_css_last landing "$landdir"
  check_tokens_defined landing "$landdir/myst-theme.css"
  check_blue_coverage landing "$landdir" "$landdir/myst-theme.css"
  check_landing_classes landing "$landdir" "$landdir/myst-theme.css"
  check_css_urls landing "$landdir"
  check_faces_served landing "$landdir"
  check_theme_css_served landing "$landdir"
fi

exit $fail
