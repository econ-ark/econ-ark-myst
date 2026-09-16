#import "@preview/pubmatter:0.2.2"

#let venueUrl = "https://econ-ark.org";
#let venueLogo = image("logo.png");
// Econ-ARK brand palette, from econ-ark.org assets/sass/_variables.scss
#let arkBlue = rgb("#1f476b");
#let arkLightBlue = rgb("#00aeef");
#let arkPink = rgb("#ed217c");
#let arkGreen = rgb("#39b54a");
#let arkYellow = rgb("#fcb040");
#let arkGrey = rgb("#676470");
// Fonts fall back to ones bundled with Typst when Roboto is not installed
#let sansFont = ("Roboto", "Libertinus Serif");
#let serifFont = ("Libertinus Serif", "New Computer Modern");

#let leftCaption(it) = context {
  set text(size: 8pt)
  set align(left)
  set par(justify: true)
  text(weight: "bold")[#it.supplement #it.counter.display(it.numbering)]
  "."
  h(4pt)
  set text(fill: black.lighten(20%), style: "italic")
  it.body
}

#let fullwidth(it) = {
  place(top, dx: -30%, float: true, scope: "parent",
  box(width: 135%, it))
}

#let smallTableStyle = (
  map-cells: cell => {
    if (cell.y == 0) {
      return (..cell, content: strong(text(cell.content, 5pt)))
    }
    (..cell, content: text(cell.content, 5pt))
  },
  auto-vlines: false,
  map-hlines: line => {
    if (line.y == 0 or line.y == 1) {
      line.stroke = gray + 1pt;
    } else {
      line.stroke = 0pt;
    }
    return line
  },
)

#let template(
  frontmatter: (),
  heading-numbering: "1.1.1",
  kind: none,
  jel: none,
  paper-size: "us-letter",
  page-start: none,
  max-page: none,
  // The paper's content.
  body
) = {
  let fm = pubmatter.load(frontmatter)
  // pubmatter.load drops a document-level github and defaults a missing date to today
  let github = frontmatter.at("github", default: none)
  let has-date = "date" in frontmatter
  let dates = none
  if (has-date and type(fm.date) == datetime) {
    dates = ((title: "Published", date: fm.date),)
  }

  // Set document metadata.
  set document(title: fm.title, author: fm.authors.map(author => author.name))
  let theme = (color: arkBlue, font: sansFont)
  if (page-start != none) {counter(page).update(page-start)}
  state("THEME").update(theme)
  set page(
    paper: paper-size,
    margin: (left: 25%),
    header: pubmatter.show-page-header(fm),
    footer: block(
      width: 100%,
      stroke: (top: 1pt + gray),
      inset: (top: 8pt, right: 2pt),
      context [
        #set text(font: theme.font, size: 9pt, fill: gray.darken(50%))
        #pubmatter.show-spaced-content((
          if("venue" in fm) {emph(fm.venue)},
          if(has-date and fm.date != none) {fm.date.display("[month repr:long] [day], [year]")}
        ))
        #h(1fr)
        #counter(page).display()
      ]
    ),
  )
  let logo = [
    #venueLogo
    #align(center)[
      #text(size: 8pt, weight: "light", font: theme.font)[#link(venueUrl, venueUrl)]
    ]
    #v(13pt)
  ]

  show link: it => [#text(fill: theme.color)[#it]]
  show ref: it => {
    if (it.element == none)  {
      // This is a citation showing 2024a or [1]
      show regex("([\d]{1,4}[a-z]?)"): it => text(fill: theme.color, it)
      it
      return
    }
    // The rest of the references, like `Figure 1`
    set text(fill: theme.color)
    it
  }

  // Set the body font.
  set text(font: serifFont, size: 10pt)
  // Configure equation numbering and spacing.
  set math.equation(numbering: "(1)")
  show math.equation: set block(spacing: 1em)

  // Configure lists.
  set enum(indent: 10pt, body-indent: 9pt)
  set list(indent: 10pt, body-indent: 9pt)

  // Configure headings.
  set heading(numbering: heading-numbering)
  show heading: it => context {
    let loc = here()
    // Find out the final number of the heading counter.
    let levels = counter(heading).at(loc)
    set text(10pt, weight: 400, font: theme.font)
    if it.level == 1 [
      // We don't want to number the acknowledgment section.
      #let is-ack = it.body in ([Acknowledgment], [Acknowledgement], [Acknowledgments], [Acknowledgements], [Declaration of Competing Interest])
      #set text(if is-ack { 10pt } else { 12pt }, fill: theme.color, weight: "semibold")
      #show: block.with(above: 20pt, below: 13.75pt, sticky: true)
      #if it.numbering != none and not is-ack {
        numbering(heading-numbering, ..levels)
        [.]
        h(7pt, weak: true)
      }
      #it.body
    ] else if it.level == 2 [
      #set par(first-line-indent: 0pt)
      #set text(style: "italic")
      #show: block.with(above: 15pt, below: 13.75pt, sticky: true)
      #if it.numbering != none {
        numbering(heading-numbering, ..levels)
        [.]
        h(7pt, weak: true)
      }
      #it.body
    ] else [
      #show: block.with(above: 15pt, below: 13.75pt, sticky: true)
      #if it.level == 3 {
        numbering(heading-numbering, ..levels)
        [. ]
      }
      _#(it.body)_
    ]
  }
  place(
    top,
    dx: -33%,
    float: false,
    box(width: 27%, logo),
  )

  // Title and subtitle
  pubmatter.show-title-block(fm)

  let corresponding = pubmatter.get-corresponding-author(fm)
  let margin = (
    if corresponding != none and "email" in corresponding {
      (
        title: "Correspondence to",
        content: [
          #corresponding.name\
          #link("mailto:" + corresponding.email)[#corresponding.email]
        ],
      )
    },
    if "license" in fm and fm.license != none {
      (
        title: [License #h(1fr) #pubmatter.show-license-badge(fm)],
        content: [
          #set par(justify: true)
          #set text(size: 7pt)
          #pubmatter.show-copyright(fm)
        ]
      )
    },
    if github != none {
      (
        title: "Code Availability",
        content: [
          Source code available:\
          #link(github, github)
        ],
      )
    },
  ).filter((m) => m != none)

  place(
    left + bottom,
    dx: -33%,
    dy: -10pt,
    box(width: 27%, {
      set text(font: theme.font)
      if (kind != none) {
        show par: set par(spacing: 0em)
        text(11pt, fill: theme.color, weight: "semibold", smallcaps(kind))
        parbreak()
      }
      if (dates != none) {
        grid(columns: (40%, 60%), gutter: 7pt,
          ..dates.enumerate().map(((i, d)) => {
            let weight = if (i == 0) { "bold" } else { "light" }
            (
              text(size: 7pt, fill: theme.color, weight: weight, d.title),
              text(size: 7pt, d.date.display("[month repr:short] [day], [year]"))
            )
          }).flatten()
        )
      }
      v(2em)
      grid(columns: 1, gutter: 2em, ..margin.map(side => {
        text(size: 7pt, {
          if ("title" in side) {
            text(fill: theme.color, weight: "bold", side.title)
            [\ ]
          }
          set enum(indent: 0.1em, body-indent: 0.25em)
          set list(indent: 0.1em, body-indent: 0.25em)
          side.content
        })
      }))
    }),
  )

  if ("abstracts" in fm or "keywords" in fm or jel != none) {
    if ("abstracts" in fm) {
      box(inset: (top: 16pt, bottom: 16pt), stroke: (top: 0.5pt + gray.lighten(30%), bottom: 0.5pt + gray.lighten(30%)), pubmatter.show-abstracts(fm))
    }
    pubmatter.show-keywords(fm)
    if (jel != none) {
      parbreak()
      text(size: 9pt, font: theme.font, {
        text(fill: theme.color, weight: "semibold", "JEL Codes")
        h(8pt)
        jel
      })
    }
    v(10pt)
  }

  show par: set par(spacing: 1.4em, justify: true)

  show raw.where(block: true): (it) => {
      set text(size: 7pt)
      set align(left)
      block(sticky: true, fill: luma(240), width: 100%, inset: 10pt, radius: 1pt, it)
  }
  show figure.caption: leftCaption
  show figure.where(kind: "table"): set figure.caption(position: top)
  set figure(placement: auto)

  set bibliography(title: text(10pt, "References"), style: "chicago-author-date")
  show bibliography: (it) => {
    set text(8pt)
    set block(spacing: 0.9em)
    it
  }

  // Display the paper's contents.
  body
}
