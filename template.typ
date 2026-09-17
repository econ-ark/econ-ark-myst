[#- macro s(value) -#]"[- value | replace("\\", "\\\\") | replace('"', '\\"') -]"[#- endmacro -#]
#import "econark.typ": *

[-IMPORTS-]

// MyST's content sets figure breakability from this binding; short tables must not split across pages
#let breakableDefault = false
// Theorem-like blocks in flow, replacing the floating boxes defined in the imports above
#let proof = arkProof

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

// Every frontmatter string goes through s(), which escapes backslashes and double quotes for a Typst string
#show: template.with(
  frontmatter: (
    title: [-s(doc.title)-],
  [# if parts.abstract #]
    abstract: [
      [-parts.abstract-]
    ],
  [# endif #]
  [# if doc.subtitle #]
    subtitle: [-s(doc.subtitle)-],
  [# endif #]
  [# if doc.short_title #]
    short-title: [-s(doc.short_title)-],
  [# endif #]
  [# if doc.venue.title #]
    venue: [-s(doc.venue.title)-],
  [# endif #]
  [# if doc.open_access !== undefined #]
    open-access: [-doc.open_access-],
  [# endif #]
  [# if doc.github !== undefined #]
    github: [-s(doc.github)-],
  [# endif #]
  [# if doc.doi #]
    doi: [-s(doc.doi)-],
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
      [#- for keyword in doc.keywords -#][-s(keyword)-],[#- endfor -#]
    ),
  [# endif #]
    authors: (
  [# for author in doc.authors #]
      (
        name: [-s(author.name)-],
  [# if author.orcid #]
        orcid: [-s(author.orcid)-],
  [# endif #]
  [# if author.email #]
        email: [-s(author.email)-],
  [# endif #]
  [# if author.note #]
        note: [-s(author.note)-],
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
        name: [-s(aff.name)-],
  [# if aff.ror #]
        ror: [-s(aff.ror)-],
  [# endif #]
      ),
  [# endfor #]
    ),
  [# if doc.license.content #]
    license: (id: [-s(doc.license.content.id)-], name: [-s(doc.license.content.name)-], url: [-s(doc.license.content.url)-]),
  [# endif #]
  ),
  [# if options.kind #]
  kind: [-s(options.kind)-],
  [# endif #]
  [# if doc.tags #]
  jel: ([#- for code in doc.tags -#][-s(code)-],[#- endfor -#]),
  [# endif #]
  [# if options.linenumbers #]
  linenumbers: true,
  [# endif #]
  [# if doc.binder #]
  binder: [-s(doc.binder)-],
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

#let backMatter = [
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
#bibliography([-s(doc.bibtex)-])
[# endif #]
]

// The back matter and references go before an <appendix> marker, or at the end when there is none.
// Show rules and labels, unlike names, also reach articles included in a multi-article export.
#show <appendix>: it => backMatter + it

[-CONTENT-]

#context if query(<appendix>).len() == 0 { backMatter }
