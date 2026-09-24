# Code quality

Adapted from [Sentry's code-review skill](https://github.com/getsentry/skills/blob/main/skills/code-review/SKILL.md) for review of an existing codebase. Apply its risk-focused problem, design, test, and feedback principles to the assigned part. Its pull-request approval rules and change-only scope do not apply here.

## What to inspect

- **Correctness and reliability:** Reachable exceptions, null or bounds errors, lost errors, unintended side effects, and behavior that conflicts with a caller's contract.
- **Performance:** N+1 queries, unbounded or quadratic work, and avoidable allocations on meaningful paths. Establish the input scale or call frequency before reporting.
- **Security:** Plausible injection, authorization gaps, unsafe data handling, and secret exposure. Trace the actual trust boundary and existing protections.
- **Design and compatibility:** Component interactions, architectural fit, and existing API, data, or schema contracts that the part may violate. Give special attention to security-sensitive and performance-critical paths.
- **Tests:** Whether meaningful business rules, integration boundaries, edge cases, and critical user paths are verified. Identify the specific failure a missing test could allow; a low test count alone is not a finding.

## Finding threshold

For each candidate, trace a plausible execution path and check safeguards, framework behavior, tests, and repository conventions. Report only a concrete risk with evidence, likely impact, and an actionable change or test. Match severity to impact and likelihood. Phrase uncertain conclusions as open questions. Do not flag style preferences, demand tests without naming the behavior they protect, or treat every possible exception as a finding.

## Example

```python
def checkout(cart, customer=None):
    order = save_order(cart, customer)
    send_receipt(customer.email, order)  # Fails when customer is None
    return order
```

This is a finding if guest checkout is supported and no earlier guard supplies a customer. Trace the real call path and safeguards before reporting the runtime failure; propose handling guest orders explicitly.
