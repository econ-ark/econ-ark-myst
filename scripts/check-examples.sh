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

# Text the full example must contain; each is produced by a different template feature.
ANCHORS=(
  'Buffer Stock Saving with Heterogeneous'
  'Reproduce this paper'
  'JEL codes'
  'Proposition 1 (Concavity)'
  'Declaration of generative AI use'
  'Carroll 1997'
  'References'
  'Appendix A derives the Euler'
  'Appendix A Derivation'
)

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

  seeded=${good//Proposition 1 (Concavity)/}
  out=$(check_text seeded "$seeded" "${ANCHORS[@]}")
  if grep -q "FAIL.*missing 'Proposition 1" <<<"$out"; then
    ok "self-test: a missing anchor is caught"
  else
    bad "self-test: a missing anchor went undetected"
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
