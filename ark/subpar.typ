// Shadows the subpar module MyST calls as `subpar.grid`. Typst refuses `dict.key(..)`, so the
// binding has to be a module, and importing a file is what makes a module: hence this one. The
// version is pinned here, since a document with no subfigure has no imports file to take it from.
#import "figures.typ": arkSubparGrid
#import "@preview/subpar:0.2.2"

#let grid = arkSubparGrid(subpar)
