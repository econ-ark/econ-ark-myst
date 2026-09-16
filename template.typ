#import "econark.typ": *

[-IMPORTS-]

// MyST's content sets figure breakability from this binding; short tables must not split across pages
#let breakableDefault = false

#let tableStyle = (
  map-cells: cell => {
    if (cell.y == 0) {
      return (..cell, content: strong(text(cell.content, 9pt)))
    }
    (..cell, content: text(cell.content, 9pt))
  },
  auto-vlines: false,
  map-hlines: line => {
    if (line.y == 0 or line.y == 1) {
      line.stroke = arkGrey + 0.75pt;
    } else {
      line.stroke = 0pt;
    }
    return line
  },
)

#show: template.with(
  frontmatter: (
    title: "[-doc.title-]",
  [# if parts.abstract #]
    abstract: [
      [-parts.abstract-]
    ],
  [# endif #]
  [# if doc.subtitle #]
    subtitle: "[-doc.subtitle-]",
  [# endif #]
  [# if doc.short_title #]
    short-title: "[-doc.short_title-]",
  [# endif #]
  [# if doc.venue.title #]
    venue: "[-doc.venue.title-]",
  [# endif #]
  [# if doc.open_access !== undefined #]
    open-access: [-doc.open_access-],
  [# endif #]
  [# if doc.github !== undefined #]
    github: "[-doc.github-]",
  [# endif #]
  [# if doc.doi #]
    doi: "[-doc.doi-]",
  [# endif #]
  [# if doc.date #]
    date: datetime(
      year: [-doc.date.year-],
      month: [-doc.date.month-],
      day: [-doc.date.day-],
    ),
  [# endif #]
  [# if doc.keywords #]
    keywords: (
      [#- for keyword in doc.keywords -#]"[-keyword-]",[#- endfor -#]
    ),
  [# endif #]
    authors: (
  [# for author in doc.authors #]
      (
        name: "[-author.name-]",
  [# if author.orcid #]
        orcid: "[-author.orcid-]",
  [# endif #]
  [# if author.email #]
        email: "[-author.email-]",
  [# endif #]
  [# if author.note #]
        note: "[-author.note-]",
  [# endif #]
  [# if author.corresponding #]
        corresponding: [-author.corresponding.value-],
  [# endif #]
  [# if author.equal_contributor #]
        equal-contributor: [-author.equal_contributor-],
  [# endif #]
  [# if author.affiliations #]
        affiliations: ([#- for aff in author.affiliations -#]"[-aff.index-]"[#- if not loop.last -#],[#- endif -#][#- endfor -#]),
  [# endif #]
      ),
  [# endfor #]
    ),
    affiliations: (
  [# for aff in doc.affiliations #]
      (
        id: "[-aff.index-]",
        name: "[-aff.name-]",
  [# if aff.ror #]
        ror: "[-aff.ror-]",
  [# endif #]
      ),
  [# endfor #]
    ),
  [# if doc.license.content #]
    license: (id: "[-doc.license.content.id-]", name: "[-doc.license.content.name-]", url: "[-doc.license.content.url-]"),
  [# endif #]
  ),
  [# if options.kind #]
  kind: "[-options.kind-]",
  [# endif #]
  [# if doc.tags #]
  jel: ([#- for code in doc.tags -#]"[-code-]",[#- endfor -#]),
  [# endif #]
  [# if options.linenumbers #]
  linenumbers: true,
  [# endif #]
  [# if doc.binder #]
  binder: "[-doc.binder-]",
  [# endif #]
  [# if parts.title_note #]
  title-note: [
    [-parts.title_note-]
  ],
  [# endif #]
  [# if doc.first_page #]
  page-start: [-doc.first_page-],
  [# endif #]
)

[-CONTENT-]

[# if parts.acknowledgments #]
#heading(numbering: none)[Acknowledgments]

[-parts.acknowledgments-]
[# endif #]

[# if parts.data_availability #]
#heading(numbering: none)[Data availability]

[-parts.data_availability-]
[# endif #]

[# if parts.declaration #]
#heading(numbering: none)[Declaration of competing interest]

[-parts.declaration-]
[# endif #]

[# if parts.ai_declaration #]
#heading(numbering: none)[Declaration of generative AI use]

[-parts.ai_declaration-]
[# endif #]

[# if doc.bibtex #]
#bibliography("[-doc.bibtex-]")
[# endif #]
