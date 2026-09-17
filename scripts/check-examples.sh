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
  'Proposition 1 (Concavity)'
  'Declaration of generative AI use'
  'Carroll 1997'
  'References'
  'Appendix A derives the Euler'
  'Appendix A Derivation'
  'Key points'
  'Cite as'
  'Working paper'
  'arXiv:2609.00000'
  'Non-technical summary'
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

# A table taller than a page must break: its first and last rows land on different pages.
# An unbreakable one overflows the page foot, where its rows still extract as text, so a text search misses it.
check_breaks() {
  local name=$1 pdf=$2 first=$3 last=$4 pages p text pfirst="" plast=""
  pages=$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')
  for ((p = 1; p <= ${pages:-0}; p++)); do
    text=$(pdftotext -layout -f "$p" -l "$p" "$pdf" - 2>/dev/null | tr -s "[:space:]" " ")
    grep -qF -- "$first" <<<"$text" && [ -z "$pfirst" ] && pfirst=$p
    grep -qF -- "$last" <<<"$text" && plast=$p
  done
  if [ -n "$pfirst" ] && [ -n "$plast" ] && [ "$plast" -gt "$pfirst" ]; then
    ok "$name: table breaks from page $pfirst to page $plast"
  else
    bad "$name: '$first' and '$last' are not on successive pages (pages ${pfirst:-none} and ${plast:-none}), so the table did not break"
  fi
}

# A caption above a table that breaks must stay on the page where the table's first row is
check_same_page() {
  local name=$1 pdf=$2 caption=$3 row=$4 pages p text pcap="" prow=""
  pages=$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')
  for ((p = 1; p <= ${pages:-0}; p++)); do
    text=$(pdftotext -layout -f "$p" -l "$p" "$pdf" - 2>/dev/null | tr -s "[:space:]" " ")
    [ -z "$pcap" ] && grep -qF -- "$caption" <<<"$text" && pcap=$p
    [ -z "$prow" ] && grep -qF -- "$row" <<<"$text" && prow=$p
  done
  if [ -n "$pcap" ] && [ "$pcap" = "$prow" ]; then
    ok "$name: caption and first row share page $pcap"
  else
    bad "$name: caption on page ${pcap:-none} but first row on page ${prow:-none}, so the caption is orphaned"
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

  out=$(check_pdf seeded "$EXAMPLES/exports/does-not-exist.pdf")
  if grep -q 'FAIL.*not written' <<<"$out"; then
    ok "self-test: a missing PDF is caught"
  else
    bad "self-test: a missing PDF went undetected"
  fi
}

for tool in myst pdftotext pdfinfo; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool"; exit 2; }
done

if [ "${1:-}" = "--self-test" ]; then
  self_test
else
  (cd "$EXAMPLES" && rm -rf _build && myst build --typst) >/dev/null 2>&1
  check_pdf paper "$PAPER" "${ANCHORS[@]}"
  check_pdf minimal "$MINIMAL" 'Minimal Example'
  check_pdf tall-table "$TALL" 'Case 35' 'Text after the table'
  check_breaks tall-table "$TALL" 'Case 1 A description' 'Case 35 A description'
  check_same_page tall-table "$TALL" 'Every case, one row each.' 'Case 1 A description'
  if ! git -C "$ROOT" diff --quiet -- examples/exports/paper.pdf; then
    committed=$(mktemp)
    git -C "$ROOT" show HEAD:examples/exports/paper.pdf >"$committed"
    if diff <(pdftotext -layout "$committed" - 2>/dev/null) <(pdftotext -layout "$PAPER" - 2>/dev/null) >/dev/null; then
      echo "note  examples/exports/paper.pdf differs in bytes only, the text is unchanged (usually a different font file version)"
    else
      echo "note  examples/exports/paper.pdf text changed; commit it if the change is intended:"
      diff <(pdftotext -layout "$committed" - 2>/dev/null) <(pdftotext -layout "$PAPER" - 2>/dev/null) | head -20
    fi
    rm -f "$committed"
  fi
fi

exit $fail
