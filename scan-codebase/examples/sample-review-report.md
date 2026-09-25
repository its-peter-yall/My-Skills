VERDICT: BAD
Categorized by Concerns:
DEAD-CODE: MINIMAL
HANGING-CODE: NONE
CODE-QUALITY: CRITICAL

# order-checkout Review

## Scope
- **Owned Paths:**
  - `src/orders/**/*.ts`
  - `src/controllers/orderController.ts`
  - `tests/unit/orders/**/*.test.ts`
  - `tests/integration/checkout.test.ts`
- **Selected Concerns:** `DEAD-CODE`, `HANGING-CODE`, `CODE-QUALITY`
- **Context Inspected:** `src/models/Order.ts`, `src/services/paymentClient.ts`

---

## Confirmed Findings

### order-checkout-001 — Unhandled Null Dereference in Guest Order Email Confirmation
- **Concern:** `CODE-QUALITY`
- **Severity:** High
- **Evidence:** `src/orders/orderService.ts:142`
  ```typescript
  const customer = await userRepository.findById(order.customerId);
  await emailService.sendOrderReceipt(customer.email, order);
  ```
  In guest checkouts, `order.customerId` is `null`. `userRepository.findById(null)` returns `null`, causing `customer.email` to throw `TypeError: Cannot read properties of null (reading 'email')` after payment authorization has already occurred.
- **Impact:** Guest checkout transactions complete financial capture but fail with a 500 error at the confirmation stage, leaving the user with an error screen and preventing order email delivery.
- **Suggested Direction:** Use `order.guestEmail` when `order.customerId` is null, or encapsulate customer contact resolution in a helper that handles both registered and guest checkouts.

### order-checkout-002 — Stale Abandoned Cart Calculation Helper
- **Concern:** `DEAD-CODE`
- **Severity:** Low
- **Evidence:** `src/orders/cartUtils.ts:58`
  `function calculateV1CartAbandonment(cart: Cart): number`
  This helper function has no internal callers or exports. Search across the repository reveals no invocations since the migration to `v2CartWorkflow`.
- **Impact:** Unnecessary maintenance overhead and slight confusion for developers modifying cart calculations.
- **Suggested Direction:** Safely delete `calculateV1CartAbandonment`.

---

## Open Questions
- `src/orders/discountPolicy.ts:89`: `applyPromotionalRebate` references an external promo code service endpoint that returns a 404 in the staging environment. Need team confirmation whether this promotion service is still active or decommissioned.

---

## Validation and Coverage
- **Checks Run:** Executed `npm test -- tests/unit/orders/` (14 passing tests, 0 failures). Ran targeted TypeScript typecheck (`npx tsc --noEmit`).
- **Coverage Limitations:** Did not execute full end-to-end integration suite due to external payment sandbox dependency requirements.
