---
title: Buffer Stock Saving with Heterogeneous Agents
subtitle: An example of the Econ-ARK MyST template
short_title: Buffer Stock Saving
downloads:
  - title: PDF
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

Households save more when their income is uncertain. This paper shows how much more, and how quickly the endogenous grid method computes it.

+++ {"part": "keypoints"}

- A buffer of wealth protects households against bad income draws.
- The endogenous grid method solves the model without root finding.
- Patience, returns and risk set the size of the buffer.

+++ {"part": "dedication"}

For everyone who waited for the solver to converge.

+++ {"part": "epigraph"}

All models are wrong, but some are useful. George Box

+++ {"part": "acknowledgments"}

We thank the Econ-ARK community for comments.

+++ {"part": "data_availability"}

All code needed to reproduce the results is in the repository linked in the margin.

+++

# Introduction

Precautionary saving arises when income risk interacts with a convex marginal utility [@Carroll1997]. The endogenous grid method [@Carroll2006] makes such models cheap to solve, because it replaces root finding with an inversion of the Euler equation.[^egm] Households hold a buffer of wealth against bad income draws [@Carroll1997; @Carroll2006]. The size of that buffer depends on patience, the return on saving and the degree of risk.

[^egm]: The method inverts the first-order condition on a grid of end-of-period assets rather than solving it on a grid of market resources. `IndShockConsumerType` applies it to Section 2's model.

# Model

The consumer maximizes expected discounted utility subject to the budget constraint

```{math}
:label: eq-bellman
v(m_t) = \max_{c_t} \; u(c_t) + \beta \mathbb{E}_t \left[ v(m_{t+1}) \right],
\qquad m_{t+1} = R (m_t - c_t) + y_{t+1}.
```

@eq-bellman implies the Euler equation $u'(c_t) = \beta R \, \mathbb{E}_t[u'(c_{t+1})]$. Under constant relative risk aversion, $u(c) = c^{1-\rho}/(1-\rho)$.

## Calibration

:::{table} Baseline calibration.
:label: tbl-calibration

| Parameter | Description            | Value |
|-----------|------------------------|-------|
| $\beta$   | Discount factor        | 0.96  |
| $R$       | Gross interest factor  | 1.03  |
| $\rho$    | Relative risk aversion | 2.00  |
:::

### Sources of the parameters

Both the discount factor and the interest factor follow @Carroll1997, while we set risk aversion to the value the literature uses most often.

# Results

@tbl-calibration lists the parameters used in the solution, which come from the 1990's literature. @prop-concave describes the shape of the solution, and @fig-solution shows it at that calibration.

:::{prf:proposition} Concavity
:label: prop-concave
If income risk is present, the consumption function is strictly concave. Its slope falls toward the perfect foresight marginal propensity to consume as wealth grows.
:::

:::{prf:proof}
See @Carroll1997 for the argument under constant relative risk aversion.
:::

:::{note}
Admonitions take a rule in the palette rather than the filled box MyST draws by default. Econ-ARK blue carries this kind and `important`.
:::

:::{tip}
Green carries `tip`, `hint` and `seealso`.
:::

:::{warning}
Orange carries `attention`, `caution` and this kind.
:::

:::{danger}
Pink carries this kind and `error`.
:::

:::{figure}
:label: fig-solution

(fig-policy)=
![The consumption function](../logo.png)

(fig-value)=
![The value function](../logo.png)

Solution at the calibration of @tbl-calibration, over the same range of market resources.
:::

Buffer stock
: Wealth an impatient consumer facing income risk holds against a bad draw, toward which wealth returns from either side.

Perfect foresight
: Section 2's problem with income risk removed, which @Carroll1997 treats as the limiting case.

> Prudence and impatience together pin down a target level of wealth, which the consumer saves toward from below and spends down toward from above.

```python
from HARK.ConsumptionSaving.ConsIndShockModel import IndShockConsumerType

agent = IndShockConsumerType()  # the 1990's calibration of Table 1
agent.solve()
```

{raw:typst}`@app-euler` derives the Euler equation.

:::{raw:typst}
#metadata("appendix") <appendix>
:::

(app-euler)=
# Derivation of the Euler equation

The first-order condition for $c_t$ in @eq-bellman sets $u'(c_t)$ equal to $\beta R \, \mathbb{E}_t[v'(m_{t+1})]$. The envelope condition gives $v'(m_t) = u'(c_t)$, and substituting it yields the Euler equation.

+++ {"part": "declaration"}

The authors report no competing interests.

The authors used a large language model to draft the example text of this template, and reviewed
every sentence before release. A journal asking for these as separate statements gets them as
separate paragraphs, which is why this part carries two.

+++
