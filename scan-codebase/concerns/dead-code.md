# Dead code

Find maintained implementation, configuration, or tests that are no longer reachable or used through any supported entry point. Candidates include uncalled private functions, unused modules, obsolete feature branches, stale configuration keys, and scripts with no documented or automated invocation.

Before reporting, trace imports and callers, routes, CLI registration, dependency injection, reflection, plugin discovery, serialization, templates, jobs, external/public API use, and test-only use as applicable. A text search with no matches is a lead, not proof. Treat public exports and documented extension points as potentially used outside the repository.

Report the owned code and the evidence that its execution or usage path is absent, the maintenance or behavioral impact, and a safe removal or verification direction. Put uncertain external use under open questions. Do not report a whole feature as dead merely because it is disabled by current configuration when it remains supported.

## Example

```python
def legacy_total(items):
    return sum(item.price for item in items)  # Candidate dead code

def total(items):
    return sum(item.discounted_price for item in items)

def checkout(items):
    return charge(total(items))
```

`legacy_total` becomes a finding only after checking other callers, exports, tests, and dynamic registrations. Its absence from `checkout` alone is insufficient.
