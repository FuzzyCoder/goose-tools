# Statistical Methods Reference (Stata to Python + R)

## Table of Contents
1. [Statistical Methods Table](#1-statistical-methods-table)

---

## 1. Statistical Methods Table

| Stata | Python | R |
|-------|--------|---|
| `ttest var, by(grp)` | `scipy.stats.ttest_ind(..., equal_var=True)` | `t.test(..., var.equal=TRUE)` |
| `tab a b, chi2` | `scipy.stats.chi2_contingency(..., correction=False)` | `chisq.test(..., correct=FALSE)` |
| `mixed y x \|\| id:` | `MixedLM(...).fit(reml=False)` | `lmer(..., REML=FALSE)` |
| `mixed y x \|\| id: x` (random slope) | `re_formula="~x"` | `(1+x\|id)` |
| LR test | compare log-likelihoods from ML fits | `anova(m1, m2)` on REML=FALSE models |

Always use ML (not REML) fits when reporting LR statistics; document any deviation from Stata boundary-aware LR behavior.

Last Updated: 2026.05.04 @ 03:16:40
