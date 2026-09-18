// A fallback for mystmd 1.10.1, which sets the IMPORTS flag for a page with math macros but writes
// this file only for a page with a table or a subfigure. Without a copy here that page imports a
// file nobody wrote and the compile dies before a PDF exists. MyST overwrites it when it has packages.
