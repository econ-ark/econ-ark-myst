// Shadows the subpar module MyST calls as `subpar.grid`. Typst refuses `dict.key(..)`, so the
// binding has to be a module, and importing a file is what makes a module: hence this one.
// The version stays MyST's own, since the wrapped function comes from the imports file it wrote.
#import "econark.typ": arkSubparGrid
#import "myst-imports.typ" as mystImports

#let grid = arkSubparGrid(dictionary(mystImports).at("subpar", default: none))
