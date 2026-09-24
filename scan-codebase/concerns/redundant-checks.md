# Redundant checks

Find repeated or unreachable guards, validations, permissions checks, and error branches whose removal would preserve the relevant contract while reducing complexity or unnecessary work.

Trace data flow and control flow across callers and callees. Confirm the earlier check dominates the later one for every supported entry path and that no mutation, concurrency, type narrowing, trust boundary, or distinct failure message makes the later check necessary. Validation at multiple trust boundaries and defense in depth may be intentional.

Report exactly which check is redundant, the proof that its condition is already established, and the concrete cost or confusion it causes. If equivalence cannot be established, leave it as an open question. Do not encourage removing security or input validation merely because similar code appears elsewhere.

## Example

```python
def submit(token):
    if not token:
        raise ValueError("token required")
    user = load_user(token)
    if not token:  # Candidate redundant check
        raise ValueError("token required")
    return save_submission(user)
```

The second check is redundant if `token` cannot change between checks and `load_user` cannot alter the relevant state. A check inside a separately callable function or at a new trust boundary needs its own analysis.
