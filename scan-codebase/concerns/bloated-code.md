# Bloated code

Find excess code or complexity that creates a concrete maintenance, performance, or reliability cost. Examples include repeated substantial logic, oversized routines with multiple independent responsibilities, unnecessary layers of indirection, broad state passed through unrelated paths, and costly operations that can be simplified without changing behavior.

Explain the specific cost and where it occurs. Check whether apparent repetition protects distinct contracts or whether an abstraction exists to support real variants. A long file, high line count, or personal preference alone is not evidence of bloat.

Report a bounded simplification direction, expected benefit, and any behavior that must be preserved. Avoid proposing a large refactor when a local change would address the demonstrated cost.

## Example

```python
def preview_total(items):
    subtotal = sum(item.price for item in items)
    tax = round(subtotal * TAX_RATE, 2)
    return subtotal + tax

def charge_total(items):
    subtotal = sum(item.price for item in items)
    tax = round(subtotal * TAX_RATE, 2)
    return subtotal + tax
```

The duplicated pricing rule is a candidate if both paths must stay identical and changes have to be made twice. Check whether preview and charge intentionally have different contracts before proposing a shared calculation.
