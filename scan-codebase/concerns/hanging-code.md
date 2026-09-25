# Hanging Code

## 1. Overview & Scope

Identify intended system behavior that has been left unfinished, half-wired, or disconnected from the active runtime execution path.

Unlike dead code (which was once used or is completely abandoned), hanging code represents an **incomplete or broken contract**: the system indicates an expectation of behavior, but the implementation terminates prematurely, fails to register, or lacks a vital consumer.

---

## 2. Detection Checklist (What to Look For)

Inspect your assigned part for:
- [ ] **Reachable Stub Implementations:** Active entry points, endpoints, or handlers that return placeholder values, throw `NotImplementedError`, or contain bare `TODO` comments in production-reachable paths.
- [ ] **Unregistered Handlers & Listeners:** Event handlers, message consumers, or webhook listeners that are implemented but missing from the central dispatcher, registry, or routing table.
- [ ] **Disconnected Producers & Consumers:** Pipelines where messages, queue jobs, or events are emitted by a producer, but no corresponding consumer exists to process them (or vice-versa).
- [ ] **Partial Workflow Steps:** Multi-step workflows (e.g., checkout, data import) where intermediate steps fail to pass results to subsequent stages.
- [ ] **Unwired Configuration Hooks:** Complex configuration classes or options defined to customize behavior, but whose values are never queried or respected by the active engine.

---

## 3. False-Positive Traps (What NOT to Flag)

| Trap | Investigation Requirement |
| :--- | :--- |
| **Abstract Classes & Interfaces** | Abstract methods, protocol definitions, and interface stubs designed to be overridden by subclasses are intentional. |
| **Documented Extension Points** | No-op base handlers intended for plugin authors or SDK consumers to override. |
| **Test Fixtures & Mocks** | Placeholder functions or fake handlers residing exclusively in test suites. |
| **Explicitly Disabled Features** | Stubs guarded behind feature flags or environment toggles that are deliberately turned off. |
| **A Bare `TODO` Comment** | A comment saying `// TODO: add caching` is not hanging code unless the missing code causes an active runtime failure or leaves a route in an unusable state. |

> [!NOTE]
> **Hanging Code vs. Dead Code:** If a disconnected component has no supported intended behavior and should simply be removed, classify it as **Dead Code**. If it was clearly intended to be wired into a live flow and leaves an incomplete feature or broken contract, classify it as **Hanging Code**. Never report both for the same root cause.

---

## 4. Finding Thresholds & Severity Criteria

- **High Severity (`CRITICAL`):** Reachable public API endpoints that throw unhandled stub exceptions; critical asynchronous events (e.g., payment confirmations, order releases) that are never dispatched to handlers.
- **Medium Severity (`MODERATE`):** Partially wired background tasks, admin tools, or secondary notifications that silently fail to trigger.
- **Low Severity (`MINIMAL`):** Minor placeholder routines in non-critical auxiliary features with fallback behavior.

---

## 5. Concrete Examples & Analysis

### Example A: Reachable Unimplemented Handler
```python
# --- File: src/api/reports.py ---

# Registered HTTP route in router.py
@router.post("/api/v1/reports/export")
def export_financial_report(request: ReportRequest):
    # CRITICAL: Exposed to production clients but unimplemented
    raise NotImplementedError("Export functionality coming soon")
```
- **Analysis:** The route is registered and active in production routing, but invoking it immediately results in an internal server error (500).
- **Remediation:** Either disable the route until implemented, or implement proper error handling and a structured `501 Not Implemented` response.

### Example B: Disconnected Event Listener
```python
# --- File: src/events/order_events.py ---

def on_payment_failed(event: PaymentEvent):
    log_failure(event)

def on_payment_captured(event: PaymentEvent):
    release_inventory_and_ship(event.order_id)

# Event Dispatch Registry
EVENT_HANDLERS = {
    "payment.failed": on_payment_failed,
    # BUG: on_payment_captured is never wired into the registry!
}
```
- **Analysis:** `on_payment_captured` is fully implemented to ship orders, but because it was omitted from `EVENT_HANDLERS`, successful payments never trigger inventory release.
- **Remediation:** Wire `on_payment_captured` into the `EVENT_HANDLERS` dictionary and add an integration test to verify dispatch.
