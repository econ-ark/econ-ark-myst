---
title: Minimal Example
authors:
  - name: Solo Author
math:
  '\E': '\mathbb{E}'
exports:
  - id: econ-ark-minimal
    format: typst
    template: ..
    output: _build/exports/minimal.pdf
---

# Section

A document with no abstract, email, keywords, acknowledgments or template options.

It carries one math macro and no table, the pair mystmd writes an import for and then leaves
unwritten: $\E[x] = 0$.
