// Where things sit on the page: the margins, the rail in the wide left one, and the overhang a
// wide figure takes over that rail. Every width and height measured against the text block reads
// them from here, so the page set up in template() and the boxes placed against it stay in step.
#let marginLeft = 25%
#let marginRight = 1.35in
#let marginTop = 1in
#let marginBottom = 1in
#let textColumn() = page.width - page.width * marginLeft - marginRight
#let textHeight() = page.height - marginTop - marginBottom

// The rail is in the left margin, offset from the text column and narrower than it. Both the
// placed boxes and the height measured for them read these, so the rail moves as one piece.
#let railFraction = 0.27
#let railWidthPercent = railFraction * 100%

// A wide figure spans the rail as well as the text column, so it overhangs by as much as the rail
// is offset. The three forms below are that one quantity: the box width, the shift that recentres
// a float on the text column, and the offset the rail itself is placed at.
#let railOverhang = 33%
#let wideWidth = 100% + railOverhang
#let wideShift = -railOverhang / 2
#let railOffset = -railOverhang

// The gap above and below a figure, which every placement path sets alike
#let figureSpacing = 1.4em
