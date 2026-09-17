---
title: Buffer Stock Saving with Heterogeneous Agents
subtitle: An example of the Econ-ARK MyST template
short_title: Buffer Stock Saving
date: 2026-09-16
subject: Working paper
venue:
  title: Econ-ARK Working Papers
volume: 1
issue: 3
first_page: 1
last_page: 3
doi: 10.5281/zenodo.0000000
arxiv: https://arxiv.org/abs/2609.00000
zenodo: https://zenodo.org/records/0000000
binder: https://mybinder.org/v2/gh/econ-ark/econ-ark-myst/HEAD
downloads:
  - title: Latest version
    url: https://github.com/econ-ark/econ-ark-myst/blob/main/examples/exports/paper.pdf
  - title: BibTeX
    url: https://github.com/econ-ark/econ-ark-myst/blob/main/examples/paper.bib
keywords:
  - consumption
  - precautionary saving
  - heterogeneous agents
tags:
  - C63
  - D14
  - E21
exports:
  - id: econark-pdf
    format: typst
    template: ..
    output: exports/paper.pdf
    remark: BufferStockTheory
---

+++ {"part": "abstract"}

We solve a buffer stock saving model with the endogenous grid method and show how the Econ-ARK template typesets a working paper: title block, margin notes, equations, tables, code and author-year citations.

+++ {"part": "summary"}

Households save more when their income is uncertain. This paper shows how much more, and how quickly the extra saving can be computed.

+++ {"part": "keypoints"}

- A buffer of wealth protects households against bad income draws.
- The endogenous grid method solves the model without root finding.
- Patience, returns and risk set the size of the buffer.

+++ {"part": "acknowledgement"}

We thank the Econ-ARK community for comments.

+++ {"part": "data_availability"}

All code needed to reproduce the results is in the repository linked in the margin.

+++ {"part": "declaration"}

The authors report no competing interests.

+++ {"part": "ai_declaration"}

The authors used a large language model to draft the example text of this template and reviewed every sentence before release.

+++ {"part": "title_note"}

Prepared for the Econ-ARK template documentation.

+++

# Introduction

Precautionary saving arises when income risk interacts with a convex marginal utility [@Carroll1997]. The endogenous grid method [@Carroll2006] makes such models cheap to solve, because it replaces root finding with an inversion of the Euler equation.[^egm] Households hold a buffer of wealth against bad income draws. The size of that buffer depends on patience, the return on saving and the degree of risk.

[^egm]: The method inverts the first-order condition on a grid of end-of-period assets rather than solving it on a grid of market resources. `IndShockConsumerType` applies it to Section 2's model.

# Model

The consumer maximizes expected discounted utility subject to the budget constraint

```{math}
:label: eq-bellman
v(m_t) = \max_{c_t} \; u(c_t) + \beta \mathbb{E}_t \left[ v(m_{t+1}) \right],
\qquad m_{t+1} = R (m_t - c_t) + y_{t+1}.
```

The Euler equation implied by @eq-bellman is $u'(c_t) = \beta R \, \mathbb{E}_t[u'(c_{t+1})]$, and with constant relative risk aversion $u(c) = c^{1-\rho}/(1-\rho)$.

## Calibration

:::{table} Baseline calibration.
:label: tbl-calibration

| Parameter | Description            | Value |
|-----------|------------------------|-------|
| $\beta$   | Discount factor        | 0.96  |
| $R$       | Gross interest factor  | 1.03  |
| $\rho$    | Relative risk aversion | 2.00  |
:::

# Results

@tbl-calibration lists the parameters used in the solution, which come from the 1990's literature. @prop-concave describes the shape of the solution.

:::{prf:proposition} Concavity
:label: prop-concave
If income risk is present, the consumption function is strictly concave. Its slope falls toward the perfect foresight marginal propensity to consume as wealth grows.
:::

:::{prf:proof}
See @Carroll1997 for the argument under constant relative risk aversion.
:::

```python
from HARK.ConsumptionSaving.ConsIndShockModel import IndShockConsumerType

agent = IndShockConsumerType()
agent.solve()
```

{raw:typst}`@app-euler` derives the Euler equation.

:::{raw:typst}
#metadata("appendix") <appendix>
:::

(app-euler)=
# Derivation of the Euler equation

The first-order condition for $c_t$ in @eq-bellman sets $u'(c_t)$ equal to $\beta R \, \mathbb{E}_t[v'(m_{t+1})]$. The envelope condition gives $v'(m_t) = u'(c_t)$, and substituting it yields the Euler equation.
