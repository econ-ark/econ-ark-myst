# Econ-ARK MyST Template

A Typst PDF template for Econ-ARK working papers and technical reports, for use with [MyST](https://mystmd.org).

In your `myst.yml` or article frontmatter add:

```yaml
exports:
  - id: pdf
    format: typst
    template: https://github.com/econ-ark/econ-ark-myst.git
    article: paper.md
    output: exports/paper.pdf
    kind: Working Paper
    jel: C63, D14, E21
```

Then run `myst build --typst`.

## Requirements

- Typst 0.13 or newer (tested with 0.13.1 and 0.15.1). Typst 0.12 fails inside the `pubmatter` package.
- The sans-serif font is [Roboto](https://github.com/googlefonts/roboto-3-classic). Without it, headings fall back to Libertinus Serif, which is bundled in the Typst binary.

## Frontmatter

| Field | Where it appears |
|-------|------------------|
| `title`, `subtitle`, `authors`, `affiliations` | Title block; ORCID, email and ROR icons are linked |
| `short_title` | Running header |
| `venue.title` | Footer |
| `date` | Margin ("Published") and footer |
| `keywords` | Under the abstract |
| `license` | Margin, with a Creative Commons badge |
| `github` | Margin ("Code Availability") |
| `first_page` | Starting page number |

Authors marked `corresponding: true` (or the first author with an email) appear under "Correspondence to"; `equal_contributor: true` adds a dagger.

## Options

| Option | Description |
|--------|-------------|
| `kind` | Label in the margin, for example `Working Paper` or `REMARK` |
| `jel` | JEL classification codes shown under the keywords |

## Parts

| Part | Description |
|------|-------------|
| `abstract` | Abstract block |
| `acknowledgements` | Unnumbered section after the main text |
| `declaration` | Unnumbered "Declaration of Competing Interest" section |

## Example

`examples/` contains a full example (`paper.md`) and a minimal one (`minimal.md`):

```bash
cd examples
myst build --typst
```

![](thumbnail.png)

## License

MIT; adapted from [curvenote-templates/openrxivlabs](https://github.com/curvenote-templates/openrxivlabs). See [LICENSE](LICENSE).
