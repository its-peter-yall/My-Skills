# Bloated Code

## 1. Overview & Scope

Identify unnecessary code volume, architectural over-engineering, or accidental complexity that imposes a concrete, measurable cost on codebase maintainability, cognitive load, or runtime performance.

Bloat is not merely "a lot of lines"—it is code whose current structure demands disproportionate effort to understand, test, or modify compared to the problem it solves.

---

## 2. Detection Checklist (What to Look For)

Inspect your assigned part for:
- [ ] **Substantial Duplicated Logic:** Identical or near-identical business calculations, serialization logic, or validation sequences repeated across multiple methods or files where changes must be kept in sync manually.
- [ ] **Oversized "God" Routines:** Functions or classes spanning hundreds of lines that conflate multiple distinct responsibilities (e.g., input parsing, DB querying, business validation, and email formatting all in one function).
- [ ] **Unnecessary Layers of Indirection:** Pass-through wrappers, single-implementation interfaces, or chained proxy classes that add no behavioral transformation, abstraction, or security boundary.
- [ ] **Excessive Parameter Drilling:** Passing large bundles of global state, configuration dictionaries, or context objects through multiple intermediate layers that do not use them.
- [ ] **Overly Complex Algorithms for Simple Tasks:** Convoluted custom logic where standard library utilities or straightforward linear operations would achieve identical results with lower complexity.

---

## 3. False-Positive Traps (What NOT to Flag)

| Trap | Investigation Requirement |
| :--- | :--- |
| **High Line Count Alone** | A 500-line file that is well-structured, cohesive, and easily understood is **not** bloat. Never flag a file simply because of line count. |
| **Intentional Contract Divergence** | Two functions that look similar today but serve distinct business domains or external API contracts that are expected to diverge. |
| **Abstractions Supporting True Variants** | Factory patterns or polymorphism that support real, distinct subclasses or configurable backends. |
| **Exhaustive Pattern Matching & Tables** | Large dispatch tables, state machine transitions, or exhaustive enum matches that represent necessary domain complexity. |
| **Aesthetic / Stylistic Preferences** | Preferring functional style over imperative (or vice versa) is not a bloat finding. |

---

## 4. Finding Thresholds & Severity Criteria

- **High Severity (`CRITICAL`):** Extreme duplication across critical business paths (e.g., pricing, billing, or access control) where bugs fixed in one copy are regularly forgotten in another, or severe computational bloat causing major performance degradation.
- **Medium Severity (`MODERATE`):** Convoluted multi-layered indirection or sprawling routines that significantly hinder feature development and increase defect rates during routine maintenance.
- **Low Severity (`MINIMAL`):** Localized repetition of helper calculations, minor wrapper boilerplate, or moderately verbose data transformations.

---

## 5. Concrete Example & Analysis

```python
# --- File: src/checkout/pricing.py ---

# REPETITION: Identical pricing and tax calculations duplicated across endpoints
def preview_total(items, customer_tier):
    subtotal = sum(item.price for item in items)
    if customer_tier == "VIP":
        subtotal *= 0.90
    tax = round(subtotal * TAX_RATE, 2)
    return subtotal + tax

def charge_total(items, customer_tier):
    subtotal = sum(item.price for item in items)
    if customer_tier == "VIP":
        subtotal *= 0.90
    tax = round(subtotal * TAX_RATE, 2)
    return subtotal + tax
```

### Analysis & Remediation
- **Investigation:** Both functions perform identical calculation of discount and tax, and must always stay synchronized. Having two implementations means updating the discount or tax logic requires dual edits, risking subtle discrepancy bugs.
- **Remediation:** Extract the core pricing calculation into a single, cohesive domain helper (`calculate_order_totals(items, customer_tier)`) and have both `preview_total` and `charge_total` delegate to it.
