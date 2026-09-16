# Econ-ARK MyST Template

A Typst PDF template for Econ-ARK working papers, REMARKs and technical reports, for use with [MyST](https://mystmd.org).

In your `myst.yml` or article frontmatter add:

```yaml
exports:
  - id: pdf
    format: typst
    template: https://github.com/econ-ark/econ-ark-myst.git
    article: paper.md
    output: exports/paper.pdf
    kind: Working paper
```

Then run `myst build --typst`.

## Requirements

- Typst 0.13 or newer (tested with 0.13.1 and 0.15.1). Typst 0.12 fails inside the `pubmatter` package.
- Install [Roboto](https://github.com/googlefonts/roboto-3-classic) for headings and [Libertinus Math](https://github.com/alerque/libertinus) for equations. Without them the template still compiles with fonts bundled in the Typst binary. Headings fall back to Libertinus Serif and equations to New Computer Modern Math.

## Frontmatter

| Field | Where it appears |
|-------|------------------|
| `title`, `subtitle`, `authors`, `affiliations` | Title block; ORCID, email and ROR icons are linked |
| author `note` | Starred footnote on the title, for thanks and funding |
| `short_title` | Running header |
| `venue.title` | Footer |
| `date` | Margin |
| `keywords` | Under the abstract |
| `tags` | JEL codes under the keywords. The [Econometric Society template](https://github.com/alanlujan91/econsoc_template) reads the same field, so one manuscript builds with both |
| `license` | Margin, with a Creative Commons badge |
| `github`, `binder` | "Reproduce this paper" strip under the abstract |
| `first_page` | Starting page number |

Authors marked `corresponding: true` (or the first author with an email) appear under "Correspondence"; `equal_contributor: true` adds a dagger.

## Options

| Option | Description |
|--------|-------------|
| `kind` | Label in the margin, for example `Working paper` or `REMARK` |
| `linenumbers` | Number the lines of the main text, for review drafts |

## Parts

| Part | Description |
|------|-------------|
| `abstract` | Run-in abstract under the title |
| `acknowledgments` | Unnumbered section after the main text (`acknowledgements` and `acknowledgement` also work) |
| `data_availability` | Unnumbered data availability statement |
| `declaration` | Unnumbered declaration of competing interest |
| `ai_declaration` | Unnumbered declaration of generative AI use, immediately before the references. Same part name as [elsarticle-myst](https://github.com/alanlujan91/elsarticle-myst) |
| `title_note` | Starred footnote on the title, placed before any author notes |

## Example

`examples/paper.md` exercises every field above, and `examples/minimal.md` uses as few as possible. The rendered `examples/exports/paper.pdf` is tracked. The PDF carries no creation timestamp, so rebuilding an unchanged example leaves it byte-identical.

```bash
cd examples
myst build --typst
```

![](thumbnail.png)

## License

MIT; adapted from [curvenote-templates/openrxivlabs](https://github.com/curvenote-templates/openrxivlabs). See [LICENSE](LICENSE).
