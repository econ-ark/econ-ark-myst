// Admonitions, theorem-like blocks and appendix numbering: the three things MyST hands the
// template as boxes, set here the way economics papers set them instead.
#import "brand.typ": *
#import "figures.typ": numberLabel

// Theorem-like blocks from MyST prf: directives, set in flow the way economics papers set them.
// Replaces MyST's own proof(), which floats each block to the top of the page inside a tinted box.

// amsthm's plain style, which italicises its statement, less the kinds MyST has no directive for.
// Its definition and remark styles both set upright, which is what every other kind gets here.
#let italicKinds = ("theorem", "lemma", "proposition", "corollary", "conjecture", "criterion")

// Admonitions, which MyST otherwise draws as a filled box in a colour outside the palette.
// A rule in the palette carries them instead, with the label in the same colour.

#let arkAdmonition(body, heading: none, color: arkBlue) = block(
  width: 100%,
  above: 1.2em,
  below: 1.2em,
  stroke: (left: 2pt + color),
  inset: (left: 9pt, top: 5pt, bottom: 5pt),
  {
    set par(first-line-indent: 0pt)
    if heading != none {
      block(below: 0.5em, text(font: sansFont, size: 9pt, weight: 500, fill: color, heading))
    }
    body
  },
)

// Which curve each of MyST's ten admonition kinds takes. Blue for the neutral ones, green for
// the helpful, orange for the wary and pink for the severe. The palette belongs beside the
// palette; template.typ only renames these to the bindings MyST looks up.
#let arkAdmonitions = (
  note: arkAdmonition.with(heading: [Note], color: arkBlue),
  important: arkAdmonition.with(heading: [Important], color: arkBlue),
  tip: arkAdmonition.with(heading: [Tip], color: arkCurves.at(3)),
  hint: arkAdmonition.with(heading: [Hint], color: arkCurves.at(3)),
  seealso: arkAdmonition.with(heading: [See Also], color: arkCurves.at(3)),
  attention: arkAdmonition.with(heading: [Attention], color: arkCurves.at(0)),
  caution: arkAdmonition.with(heading: [Caution], color: arkCurves.at(0)),
  warning: arkAdmonition.with(heading: [Warning], color: arkCurves.at(0)),
  danger: arkAdmonition.with(heading: [Danger], color: arkCurves.at(1)),
  error: arkAdmonition.with(heading: [Error], color: arkCurves.at(1)),
)

// color and float take the arguments MyST's own proof() accepts and ignore them: a theorem here is
// set in the flow of the text, never in a coloured box and never floated.
#let arkProof(body, heading: [], kind: "proof", supplement: "Proof", labelName: none, color: none, float: false) = {
  let note = if heading != [] { [ (#heading)] }
  if kind == "proof" {
    block(above: 1em, below: 1.2em, width: 100%, {
      set par(first-line-indent: 0pt)
      // The fixed gap keeps the square off the last word when the line is full
      [#emph(supplement)#note. #body#h(0.8em)#h(1fr)$square$]
    })
    return
  }
  let statement = if kind in italicKinds { emph(body) } else { body }
  [#show figure.where(kind: kind): it => block(above: 1.2em, below: 1.2em, width: 100%, {
      set align(left)
      set par(first-line-indent: 0pt)
      [#numberLabel(it)#note. #it.body]
    })
    #figure(kind: kind, supplement: supplement, numbering: "1", outlined: false, statement)#if labelName != none { label(labelName) }]
}

// The heading the appendices start at, as the name of its label, which an export option gives in
// place of an <appendix> marker written in the body.
#let appendixFrom = state("ark-appendix-from", none)

// Puts that marker in front of the heading carrying labelName, where template.typ prints the back
// matter, and records the name for the lettering below: a marker a show rule emits does not read as
// "before" the heading it precedes, so the lettering counts from the heading itself.
#let arkAppendixFrom(labelName, doc) = if labelName == none { doc } else {
  let target = label(labelName)
  appendixFrom.update(labelName)
  show heading: it => if it.at("label", default: none) == target {
    [#metadata(none)#label("appendix")]
    it
  } else {
    it
  }
  doc
}

// Appendix number of the heading at loc, such as "A" or "B.2", or none where the appendices have
// not started. Counted from where they start, so the author need not reset the heading counter;
// call inside context. A marker stands before the first appendix, where labelName is that appendix.
#let appendixNumber(loc) = {
  let base = none
  let markers = query(selector(<appendix>).before(loc))
  if markers.len() > 0 { base = counter(heading).at(markers.last().location()).at(0, default: 0) }
  let named = appendixFrom.get()
  if named != none {
    let heads = query(selector(label(named)).before(loc, inclusive: true))
    if heads.len() > 0 { base = counter(heading).at(heads.last().location()).at(0, default: 1) - 1 }
  }
  if base == none { return none }
  let nums = counter(heading).at(loc)
  let first = nums.at(0) - base
  if first < 1 { return none }
  (numbering("A", first), ..nums.slice(1).map(str)).join(".")
}
