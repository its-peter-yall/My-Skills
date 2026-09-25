# Dead Code

## 1. Overview & Scope

Identify maintained source code, behavior-bearing configuration, or test suites that are no longer reachable, invoked, or utilized through any supported application entry point.

Dead code increases cognitive overhead, complicates refactoring, inflates bundle size, and creates maintenance drag without providing any business or operational value.

---

## 2. Detection Checklist (What to Look For)

Inspect your assigned part for:
- [ ] **Uncalled Internal Functions & Methods:** Private or unexported helper functions, internal methods, or classes with zero callers.
- [ ] **Unreferenced Modules & Types:** File modules, type definitions, schemas, or interfaces that have no internal imports or external exposures.
- [ ] **Stale Configuration & Flags:** Configuration keys, environment variable declarations, or feature flags whose corresponding conditional code paths have been removed.
- [ ] **Orphaned Scripts & Utilities:** Standalone migration scripts, ad-hoc maintenance tools, or debugging helpers that have no documented or automated invocation mechanisms.
- [ ] **Unused Test Fixtures:** Test helpers, mocks, or assertions that no longer test any active or planned capability.

---

## 3. False-Positive Traps (What NOT to Flag)

Before confirming a dead code candidate, thoroughly investigate these common traps:

| Trap | Investigation Requirement |
| :--- | :--- |
| **Public API Exports** | Exported library functions, public SDK interfaces, and documented package entry points may have external consumers outside the repository. Record as an **Open Question** if external usage is ambiguous. |
| **Dynamic Dispatch & Reflection** | Methods called via string reflection, metadata decorators, or dynamic RPC lookups (e.g., event handlers matched by convention). A text search returning no exact match is a lead, **never** definitive proof. |
| **Dependency Injection & Plugins** | Classes registered in IoC containers or plugin registries that are resolved at runtime. |
| **Serialization & Deserialization** | Model fields or DTO properties that appear unread in code but are required for JSON/database serialization. |
| **Supported but Inactive Features** | A feature or toggle that is currently set to `false` in configuration is **not** dead code if it remains actively maintained and supported. |

---

## 4. Finding Thresholds & Severity Criteria

- **High Severity (`CRITICAL`):** Large abandoned subsystems or stale endpoints that expose security risks, confusing duplicate authentication flows, or significant operational liabilities.
- **Medium Severity (`MODERATE`):** Meaningful blocks of dead business logic, unused database models, or obsolete feature branches that confuse developers and impede refactoring.
- **Low Severity (`MINIMAL`):** Minor uncalled private helper functions, unused local variables, or stale non-critical config keys.

---

## 5. Concrete Example & Analysis

```python
# --- File: src/billing/calculator.py ---

# CANDIDATE: Unused legacy function
def legacy_calculate_total(items):
    return sum(item.price for item in items)

def calculate_discounted_total(items):
    return sum(item.discounted_price for item in items)

def process_checkout(items):
    # Only calculate_discounted_total is called in this pipeline
    return charge(calculate_discounted_total(items))
```

### Analysis & Remediation
- **Investigation:** Searching the repo confirms `legacy_calculate_total` is unexported, has zero callers across the codebase, has no dynamic references, and is not tested.
- **Confirmed Finding:** `legacy_calculate_total` is completely unreachable.
- **Remediation:** Remove the dead function and clean up any obsolete comments.
