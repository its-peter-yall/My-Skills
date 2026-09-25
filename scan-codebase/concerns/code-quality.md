# Code Quality

## 1. Overview & Scope

Audit the assigned codebase part for concrete engineering risks across **correctness, reliability, performance, security, architecture, and test coverage**.

Adapted from the principles of [Sentry's Code Review Guidelines](https://github.com/getsentry/skills/blob/main/skills/code-review/SKILL.md) for full-codebase auditing, this concern focuses on tangible production risk, data integrity, and operational health—not stylistic preferences.

---

## 2. Core Inspection Dimensions

### A. Correctness & Reliability
- **Reachable Exceptions & Null Dereferences:** Unchecked `None`/`null` dereferences, out-of-bounds array indexing, unhandled promise rejections, or uncaught exceptions on production call paths.
- **Lost Errors & Swallowed Exceptions:** Empty `catch`/`except` blocks that hide underlying failures or return partial data without logging or telemetry.
- **Broken State Management:** Race conditions, missing database transaction rollbacks, or inconsistent shared state updates during failures.

### B. Performance & Resource Management
- **N+1 Database Queries:** Loops issuing individual database queries instead of batch loading (`JOIN`, `IN`, or `select_related`).
- **Unbounded Operations & Algorithmic Traps:** Quadratic ($O(N^2)$) loops on unbounded user inputs, unbounded in-memory pagination, or loading entire database tables into RAM.
- **Resource Leaks:** Unclosed file descriptors, network connections, memory leaks in long-lived caches, or uncancelled event subscriptions.

### C. Security & Trust Boundaries
- **Injection Vulnerabilities:** Unsanitized parameters in SQL queries, command execution, or template evaluation.
- **Authentication & Authorization Gaps:** Unprotected endpoints, missing role/permission checks, or insecure direct object references (IDOR).
- **Data Protection & Secret Exposure:** Hardcoded credentials, secrets logged in plain text, or sensitive PII exposed in unauthenticated responses.

### D. Architectural Fit & Contracts
- **API & Schema Violations:** Internal components violating documented caller expectations, schema requirements, or serialization contracts.
- **Fragile Coupling:** Modules directly mutating the internal state of unrelated services rather than using explicit interfaces.

### E. Test Coverage of Critical Behaviors
- **Missing Protection for High-Risk Paths:** Critical business logic, security guards, or state transitions lacking unit or integration tests.
- *Requirement:* You must identify the **specific bug or regression** that a missing test allows; a low test count alone is never a finding.

---

## 3. False-Positive Traps (What NOT to Flag)

| Trap | Investigation Requirement |
| :--- | :--- |
| **Linters & Style Opinions** | Formatting, variable naming conventions, import ordering, or bracket placement. Linters automate these; do not report them. |
| **Theoretical Exceptions Behind Framework Guards** | A potential `null` pointer that is already caught or sanitized by an upstream framework middleware, schema validator, or router guard. |
| **Low Test Coverage Metrics Alone** | Do not flag "test coverage is only 60%". Only report when a specific, critical user flow or failure mode is completely untested. |
| **Micro-Optimizations on Infrequent Paths** | Minor allocation concerns or microsecond differences on startup scripts or low-frequency admin endpoints. |

---

## 4. Finding Thresholds & Severity Criteria

- **High Severity (`CRITICAL`):** Exploitable security vulnerability, severe data loss risk, unhandled exception in core customer flow, or catastrophic $O(N^2)$ bottleneck on critical path.
- **Medium Severity (`MODERATE`):** N+1 query in regular API route, missing error recovery leaving inconsistent state, or lack of test coverage on complex payment/state transitions.
- **Low Severity (`MINIMAL`):** Minor unhandled edge-case exception on rare input, moderate inefficiency in secondary batch job, or incomplete docstring on critical API.

---

## 5. Concrete Example & Analysis

```python
# --- File: src/orders/checkout_service.py ---

def process_checkout(cart, customer=None):
    # Guard: Persists the order successfully
    order = order_repo.create_order(cart=cart, customer=customer)
    
    # DEFECT: Unhandled AttributeError when customer is None (Guest Checkout)
    # The system supports guest checkout where customer is None!
    send_order_receipt(customer.email, order)
    
    return order
```

### Analysis & Remediation
- **Investigation:** System documentation and route definitions state that guest checkout (`customer=None`) is a supported feature. When a guest checks out, `customer.email` raises `AttributeError: 'NoneType' object has no attribute 'email'`, failing the order process after the database record has already been created.
- **Confirmed Finding:** Reachable unhandled exception in core checkout flow causing 500 error and inconsistent order delivery state.
- **Remediation:** Handle guest checkout explicitly: extract guest email from `cart.guest_email` if `customer` is `None`, or provide a safe fallback prior to dispatching receipts.
