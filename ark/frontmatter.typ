// The title block and the pieces the front matter and the margin rail are built from: run-in
// fields, rail items, the materials block, key points, author names, copyright and the citation.
#import "@preview/pubmatter:0.2.2"
#import "brand.typ": *

// A "Label  content" run-in field, which the front matter sets its abstract, summary, keywords
// and JEL codes as. One definition, so a change of label weight or colour reaches all of them.
#let labeledField(label, content, size: 8.5pt) = {
  text(font: sansFont, weight: 500, fill: arkBlue, size: size, label)
  h(0.7em)
  content
}

// A small labelled block in the margin rail
#let railItem(title, content) = {
  text(size: 7.5pt, fill: arkBlue, weight: 500, title)
  linebreak()
  text(size: 7.5pt, content)
}

// Materials under the abstract: (label, body) groups in quarter-width columns under the logo's four colours.
// All four rules show however many groups a paper has, so the block always carries the full logo palette.
// With no groups the rules alone remain, as the divider that ends the front matter.
#let materialsBlock(groups) = {
  set text(font: sansFont, size: 8pt)
  set par(first-line-indent: 0pt, justify: false, leading: 0.45em, spacing: 0.45em)
  if groups.len() > 0 {
    text(size: 8.5pt, fill: arkBlue, weight: 500, "Materials")
    v(5pt, weak: true)
  }
  grid(
    columns: (1fr,) * 4,
    column-gutter: 1.4em,
    row-gutter: 4pt,
    ..arkCurves.map(colour => line(length: 100%, stroke: 1pt + colour)),
    ..groups.map(((label, body)) => {
      text(size: 7pt, fill: arkGrey, label)
      linebreak()
      body
    }),
  )
}

// A note under a material, such as how long a dashboard takes to start
#let materialNote(body) = text(size: 6.5pt, fill: arkGrey, body)

// The keypoints part: a short list read beside the title and abstract
#let keyPoints(body, size: 8pt) = {
  set text(font: sansFont, size: size)
  set par(first-line-indent: 0pt, justify: false, leading: 0.5em, spacing: 0.7em)
  set list(marker: text(fill: arkBlue, sym.bullet), indent: 0pt, body-indent: 0.5em, spacing: 0.8em)
  // Label half a point under the text, matching the rail labels and, under the abstract, the keyword labels
  // Title case, which is what myst-theme labels this part with on the site
  text(size: size - 0.5pt, fill: arkBlue, weight: 500, "Key Points")
  v(0.6em, weak: true)
  body
}

// An author's family name with its particle, such as "van Beethoven", or else the full name
#let familyName(a) = (a.at("particle", default: none), a.at("family", default: a.name)).filter(x => x != none).join(" ")

// Authors as an author-date citation names them: "Carroll", "Carroll and Lujan", "Carroll et al."
#let shortAuthors(authors) = if authors.len() == 0 { none } else if authors.len() == 1 { familyName(authors.first()) } else if authors.len() == 2 { authors.map(familyName).join(" and ") } else { familyName(authors.first()) + " et al." }

// A field the author wrote without a full stop still has to read as a sentence where it is set
#let closeSentence(s) = if s.ends-with(regex("[.?!]")) { s } else { s + "." }

// Copyright line and license terms for the margin. The copyright field replaces the generated holder,
// and is printed as written when it already carries a copyright sign.
#let copyrightNotice(authors, year, copyright, license) = {
  let holder = if copyright == none {
    ("Copyright ©", year, shortAuthors(authors)).filter(x => x != none).map(str).join(" ")
  } else if copyright.contains("©") or lower(copyright).starts-with("copyright") {
    copyright
  } else {
    ("Copyright ©", year, copyright).filter(x => x != none).map(str).join(" ")
  }
  [#closeSentence(holder) ]
  if license != none {
    // pubmatter's wording, so existing papers read the same
    let terms = (
      "CC-BY-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format, so long as attribution is given to the creator],
      "CC-BY-NC-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format for _noncommercial purposes only_, and only so long as attribution is given to the creator],
      "CC-BY-NC-SA-4.0": [, which enables reusers to distribute, remix, adapt, and build upon the material in any medium or format for noncommercial purposes only, and only so long as attribution is given to the creator. If you remix, adapt, or build upon the material, you must license the modified material under identical terms],
      "CC-BY-ND-4.0": [, which enables reusers to copy and distribute the material in any medium or format in _unadapted form only_, and only so long as attribution is given to the creator],
      "CC-BY-NC-ND-4.0": [, which enables reusers to copy and distribute the material in any medium or format in _unadapted form only_, for _noncommercial purposes only_, and only so long as attribution is given to the creator],
    )
    [This article is distributed under the terms of the #link(license.url, license.name) license#terms.at(license.id, default: none).]
  }
}

// Chicago author-date entry for the paper itself, the style of its reference list.
// Lists up to three authors; with more, the first author and "et al."
#let citation(authors, year, title, venue, volume, issue, pages) = {
  let family = familyName
  let inverted(a) = if "family" in a { (family(a), a.at("given", default: none), a.at("suffix", default: none)).filter(x => x != none).join(", ") } else { a.name }
  let direct(a) = if "family" in a { ((a.at("given", default: none), family(a)).filter(x => x != none).join(" "), a.at("suffix", default: none)).filter(x => x != none).join(", ") } else { a.name }
  let names = if authors.len() == 1 {
    inverted(authors.first())
  } else if authors.len() <= 3 {
    let rest = authors.slice(1).map(direct)
    inverted(authors.first()) + ", " + rest.slice(0, -1).map(n => n + ", ").sum(default: "") + "and " + rest.last()
  } else {
    inverted(authors.first()) + ", et al"
  }
  [#closeSentence(names) ]
  if year != none [#year. ]
  ["#closeSentence(title)"]
  if venue != none {
    [ #emph(venue)]
    if volume != none [ #volume]
    if issue != none [ (#issue)]
    if pages != none [: #pages]
    [.]
  }
}

// pubmatter sets the authors in "semibold", which resolves by discovery order at any weight the
// text face lacks a file for. This is its title block with the authors pinned to the
// weight the rest of the template asks for.

// Footnote marks for an author's note. Typst's own "*" sequence runs * then a dagger, and
// pubmatter already prints a dagger against an equal contributor, so this one leaves it out.
#let authorNoteSymbol = n => ("*", "‡", "§", "¶").at(calc.rem(n - 1, 4))

#let titleBlock(fm) = pubmatter.with-theme(_ => {
  pubmatter.show-title(fm)
  pubmatter.show-authors(fm, weight: 500)
  pubmatter.show-affiliations(fm)
})
