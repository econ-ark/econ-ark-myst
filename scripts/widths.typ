// The two widths a figure is drawn to, in points, read out of the layout the template pages with.
// `typst eval 'query(<ark-widths>).map(it => it.value)' --in scripts/widths.typ --root .` prints
// them as JSON, which is how scripts/brand-figures.py carries them into brand/ark-figures.json.
#import "../ark/layout.typ": *

#set page(paper: "us-letter", margin: (left: marginLeft, right: marginRight))

#context [
  #metadata((
    column: textColumn().to-absolute().pt(),
    wide: (textColumn() * wideWidth).to-absolute().pt(),
  )) <ark-widths>
]
