# Hanging code

Find intended behavior that is left unfinished or disconnected. This includes reachable TODO-driven stubs, placeholder returns or exceptions, half-wired routes/jobs/handlers, feature paths whose producer has no consumer, and orphaned components that appear meant to participate in a live flow.

Trace the intended path from entry point to outcome. Check whether a stub is an intentional interface, test fixture, abstract method, planned extension point, or explicitly disabled feature. For a disconnected component, identify the missing connection or contract and corroborate intended use from nearby code, configuration, tests, or documentation. A TODO alone is not a finding.

Report the user or operational behavior that fails or cannot occur, with evidence of the broken connection or unfinished path. If the code is simply unused with no supported intended behavior, classify it as dead code instead. When both concerns are selected, report one root cause once under the concern that best explains its impact.

## Examples

```python
def export_report(request):  # Registered HTTP handler
    raise NotImplementedError("export is coming soon")
```

This is a finding if the route is enabled and users can reach it; an intentionally disabled or abstract handler is different.

```python
def on_payment_failed(event):
    log_failure(event)

HANDLERS = {"payment.failed": on_payment_failed}

def on_payment_captured(event):
    release_order(event.order_id)
```

The captured-payment path may be disconnected. Verify that this registry is the actual dispatch mechanism and that no other registration wires the handler.
