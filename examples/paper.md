---
title: Buffer Stock Saving with Heterogeneous Agents
subtitle: An example of the Econ-ARK MyST template
short_title: Buffer Stock Saving
date: 2026-09-16
venue:
  title: Econ-ARK Working Papers
keywords:
  - consumption
  - precautionary saving
  - heterogeneous agents
exports:
  - id: econark-pdf
    format: typst
    template: ..
    output: _build/exports/paper.pdf
    kind: Working Paper
    jel: C63, D14, E21
---

+++ {"part": "abstract"}

We solve a buffer stock saving model with the endogenous grid method and show how the Econ-ARK template typesets a working paper: title block, margin notes, equations, figures, tables and author-year citations.

+++ {"part": "acknowledgements"}

We thank the Econ-ARK community for comments.

+++ {"part": "declaration"}

The authors declare no competing interests.

+++

# Introduction

Precautionary saving arises when income risk interacts with a convex marginal utility [@Carroll1997]. The endogenous grid method [@Carroll2006] makes such models cheap to solve.

# Model

The consumer maximizes expected discounted utility subject to the budget constraint

```{math}
:label: eq-bellman
v(m_t) = \max_{c_t} \; u(c_t) + \beta \mathbb{E}_t \left[ v(m_{t+1}) \right],
\qquad m_{t+1} = R (m_t - c_t) + y_{t+1}.
```

The Euler equation implied by @eq-bellman is $u'(c_t) = \beta R \, \mathbb{E}_t[u'(c_{t+1})]$.

## Calibration

:::{table} Baseline calibration.
:label: tbl-calibration

| Parameter | Value |
|-----------|-------|
| $\beta$   | 0.96  |
| $R$       | 1.03  |
| $\rho$    | 2.00  |
:::

# Results

@tbl-calibration lists the parameters used in the solution.

```python
from HARK.ConsumptionSaving.ConsIndShockModel import IndShockConsumerType

agent = IndShockConsumerType()
agent.solve()
```
