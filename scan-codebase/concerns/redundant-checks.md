# Redundant Checks

## 1. Overview & Scope

Identify unnecessary, repeated, or completely unreachable conditional checks, validations, guards, and defensive branches whose elimination simplifies the control flow without compromising safety or changing the system's contract.

Redundant checks obscure the true control flow, create dead code branches, and mislead future maintainers into believing state can mutate when it cannot.

---

## 2. Detection Checklist (What to Look For)

Inspect your assigned part for:
- [ ] **Dominated Guards:** A conditional check whose outcome is strictly guaranteed by an identical or broader check executed earlier in the same call path without intervening state changes.
- [ ] **Duplicate Null / Type Checks:** Checking a variable for `null`/`undefined` multiple times within the same scope, or immediately following an assertion or type-narrowing operator that already guaranteed its presence.
- [ ] **Unreachable Else / Switch Branches:** `else` blocks or `switch` cases that can never execute because prior conditions exhaust all possible domain values or enum states.
- [ ] **Redundant Boundary Checks in Private Callees:** A private helper function that performs defensive parameter validation when all of its private callers have already sanitized and verified the input.
- [ ] **Impossible Exception Handlers:** `catch` or `except` blocks catching specific errors that the guarded code block cannot throw.

---

## 3. False-Positive Traps (What NOT to Flag)

| Trap | Investigation Requirement |
| :--- | :--- |
| **Trust Boundary Validation** | Sanitizing and validating inputs at a boundary (e.g., HTTP API controller) even if downstream clients also validate. Cross-boundary validation is good engineering, not redundancy. |
| **Defense in Depth** | Strategic sanity assertions in public library code or shared infrastructure modules that could be called by future unknown callers. |
| **State Mutation & Concurrency** | Any intervening function call that could mutate the object, execute an asynchronous callback, or modify global/shared memory before the second check. |
| **Distinct Error Contexts** | An inner check that provides a specific, user-facing error message or diagnostic telemetry that the outer check does not offer. |
| **Compiler / Type-Checker Narrowing** | Checks required by TypeScript or other static type checkers to narrow a union type within a block. |

---

## 4. Finding Thresholds & Severity Criteria

- **High Severity (`CRITICAL`):** Redundant permission or token checks that mask authorization bypasses, or conflicting nested checks that accidentally lock out valid users or cause deadlocks.
- **Medium Severity (`MODERATE`):** Dominated guards that create confusing dead branches, give false confidence about error recovery, or waste significant I/O (e.g., executing the same database check twice).
- **Low Severity (`MINIMAL`):** Minor duplicate null checks or redundant local assertions with zero performance impact.

---

## 5. Concrete Example & Analysis

```python
# --- File: src/services/user_submission.py ---

def process_submission(token: str, payload: dict):
    # Guard 1: Validates token presence
    if not token:
        raise ValueError("Authentication token is required")

    # Pure read operation: does not mutate token or session state
    user = session_store.get_user_by_token(token)
    if not user:
        raise AuthenticationError("Invalid session")

    # REDUNDANT CHECK: token presence checked again unnecessarily
    if not token:
        raise ValueError("Authentication token is required")

    return save_submission(user, payload)
```

### Analysis & Remediation
- **Investigation:** `token` is an immutable string and was already validated at the entry point of the function. No operation between Guard 1 and the second check alters `token`.
- **Confirmed Finding:** The second `if not token` check is completely dominated by the first check and can never be reached with a falsy value.
- **Remediation:** Safely delete the redundant second check to streamline the execution path.
