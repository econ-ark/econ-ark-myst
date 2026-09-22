// Set and show rules for the running text: code, links and references, body face, lists,
// definition terms, quotations and headings. Applied as `show: arkTypography.with(heading-numbering)`,
// which installs them at the point of the call, so they reach the document from there on.
#import "brand.typ": *
#import "blocks.typ": appendixNumber

// Rules for text in footnotes go here, before the title block: a footnote picks up only rules set before it
#let arkTypography(heading-numbering, site-url, doc) = {
  // Typst's stock syntax colours are off the palette, and the tokens are unreachable from a show
  // rule, so the three roles theme.css gives a listing are set from a theme file instead
  set raw(theme: "../brand/code.tmTheme")
  // Typst reads ' after a digit as a prime, so "Table 1's" would print a prime. Restore the
  // apostrophe, except in code of either kind, which a state marks because a show rule cannot see
  // its surroundings: a listing that lost its ASCII quote is source a reader cannot paste and run.
  let inCode = state("ark-code", false)
  show raw.where(block: true): it => {
    set text(font: monoFont, size: 8pt)
    inCode.update(true); it; inCode.update(false)
  }
  // Inline code keeps Typst's 0.8em against a text face of the same x-height, so it reads a shade
  // smaller than its surroundings. An empty box after _ and . lets a long name wrap without
  // adding a character to copied text.
  show raw.where(block: false): it => {
    set text(font: monoFont)
    show regex("[_.]"): s => [#s#box()]
    inCode.update(true); it; inCode.update(false)
  }
  show regex("\d's\b"): it => context if inCode.get() { it } else { it.text.slice(0, -2) + sym.quote.r.single + "s" }

  // Citations and URLs leave the document, so they are blue; internal references stay black.
  // MyST writes a cross-reference as a link carrying the target's title, never as a ref, so the
  // appendix lettering has to happen here as well as in the ref rule below.
  show link: it => if type(it.dest) == str {
    if not it.dest.starts-with("/") {
      text(fill: arkBlue, it)
    } else if site-url == none {
      // A page exported out of a multi-page project links the project's other pages by path, which
      // no PDF can follow, so the path prints as the text MyST wrote around it
      it.body
    } else {
      // The rewritten link is a link too, which this same rule takes again; its destination is a
      // web address by then, so the branch above turns it blue
      link(site-url.trim("/", at: end) + it.dest, it.body)
    }
  } else {
    context {
      let targets = query(it.dest)
      if targets.len() == 0 {
        // A reference to a label on a page the export left behind. The label is in no PDF and a
        // link to it stops the build; MyST numbered the text already, so the text prints alone
        it.body
      } else {
        let el = targets.first()
        let appendix = if el.func() == heading and el.numbering != none { appendixNumber(el.location()) }
        // The replacement is a link too, which this same rule matches; comparing against the body it
        // would build is what stops the second pass from building it again
        let lettered = [Appendix #appendix]
        if appendix == none or it.body == lettered { it } else { link(it.dest, lettered) }
      }
    }
  }
  show cite: set text(fill: arkBlue)
  // A native reference to an appendix heading reads "Appendix A" rather than "Section 3"
  show ref: it => context {
    let el = it.element
    let appendix = if el != none and el.func() == heading and el.numbering != none { appendixNumber(el.location()) }
    if appendix == none { it } else { link(it.target)[Appendix #appendix] }
  }

  // Body text: serif at 11pt keeps the measure under 80 characters
  set text(font: serifFont, size: 11pt, number-type: "lining")
  set par(justify: true, leading: 0.72em, spacing: 0.72em, first-line-indent: 1.2em)
  show math.equation: set text(font: mathFont)
  set math.equation(numbering: "(1)")
  show math.equation.where(block: true): set block(spacing: 1.1em)
  set footnote.entry(separator: line(length: 25%, stroke: 0.5pt + arkGrey))
  show footnote.entry: set text(size: 8.5pt)

  // Configure lists.
  set enum(indent: 1.2em, body-indent: 0.6em)
  set list(indent: 1.2em, body-indent: 0.6em)

  // A definition list sets its term the way the margin sets a field label, in the sans at Econ-ARK blue
  // Replacing the item drops the block Typst wraps it in, so the block comes back here
  show terms.item: it => block(above: 0.7em, below: 0.7em, {
    set par(first-line-indent: 0pt)
    text(font: sansFont, weight: 500, fill: arkBlue, it.term)
    h(0.7em)
    it.description
  })

  // A quotation carries the admonition's left rule, in grey so it reads quieter than a note
  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 0.9em),
    stroke: (left: 2pt + arkRule),
    {
      it.body
      if it.attribution != none {
        parbreak()
        text(font: sansFont, size: 9pt, fill: arkGrey, [#sym.dash.em #it.attribution])
      }
    },
  )

  // Headings: sans, sentence case as written, numbers in grey
  set heading(numbering: heading-numbering)
  show heading: it => {
    let number = if it.numbering != none {
      context {
        let appendix = appendixNumber(it.location())
        let shown = if appendix == none { counter(heading).display(it.numbering) } else if it.level == 1 { [Appendix #appendix] } else { appendix }
        text(fill: arkGrey, weight: "regular", shown)
      }
      h(0.6em)
    }
    set par(first-line-indent: 0pt, justify: false)
    if it.level == 1 {
      set text(font: sansFont, size: 13pt, weight: 500, fill: arkBlue)
      block(above: 1.8em, below: 0.9em, sticky: true, number + it.body)
    } else if it.level == 2 {
      set text(font: sansFont, size: 11pt, weight: 500)
      block(above: 1.4em, below: 0.7em, sticky: true, number + it.body)
    } else {
      set text(style: "italic")
      block(above: 1.2em, below: 0.6em, sticky: true, number + it.body)
    }
  }

  doc
}
