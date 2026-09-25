# Repository Part Map (Example)

- **Repository Root:** `/workspace/e-commerce-api`
- **Assessed Scope & Inclusions:** `src/`, `tests/`, `config/`
- **Explicit Exclusions:** `node_modules/`, `dist/`, `.git/`, `coverage/`

---

## Partitioned Review Parts

### 1. `auth-session`
- **Purpose & Contract:** Manages user authentication, token issuance, password hashing, and session validation from login endpoints to JWT verification.
- **Owned Paths:**
  - `src/auth/**/*.ts`
  - `src/controllers/authController.ts`
  - `tests/unit/auth/**/*.test.ts`
- **Estimated Size:** 12 files (~1,450 LOC / ~48 KB)
- **Entry Points:** `src/controllers/authController.ts`, `src/middleware/authenticate.ts`
- **Context Dependencies:** `src/models/User.ts`, `src/config/jwt.ts`

### 2. `order-checkout`
- **Purpose & Contract:** Handles cart checkout, inventory reservation, order state persistence, and invoice generation.
- **Owned Paths:**
  - `src/orders/**/*.ts`
  - `src/controllers/orderController.ts`
  - `tests/unit/orders/**/*.test.ts`
  - `tests/integration/checkout.test.ts`
- **Estimated Size:** 18 files (~2,200 LOC / ~76 KB)
- **Entry Points:** `src/controllers/orderController.ts`, `src/jobs/processPendingOrders.ts`
- **Context Dependencies:** `src/models/Order.ts`, `src/services/paymentClient.ts`

### 3. `payment-integration`
- **Purpose & Contract:** Integrates with third-party payment gateways, handles credit card charges, refund transactions, and webhook event ingestion.
- **Owned Paths:**
  - `src/payments/**/*.ts`
  - `src/webhooks/paymentWebhook.ts`
  - `tests/unit/payments/**/*.test.ts`
- **Estimated Size:** 9 files (~1,100 LOC / ~39 KB)
- **Entry Points:** `src/services/paymentClient.ts`, `src/webhooks/paymentWebhook.ts`
- **Context Dependencies:** `src/config/stripe.ts`

### 4. `product-catalog`
- **Purpose & Contract:** Provides catalog search, category filtering, inventory tracking, and price caching for products.
- **Owned Paths:**
  - `src/catalog/**/*.ts`
  - `src/controllers/catalogController.ts`
  - `tests/unit/catalog/**/*.test.ts`
- **Estimated Size:** 14 files (~1,800 LOC / ~60 KB)
- **Entry Points:** `src/controllers/catalogController.ts`
- **Context Dependencies:** `src/models/Product.ts`, `src/services/redisClient.ts`

---

## Cross-Part Interfaces & Shared Code Ownership
- `src/models/User.ts` is owned by `auth-session`; `order-checkout` reads it as caller context.
- `src/services/redisClient.ts` is owned by `product-catalog`; other parts read it for caching contracts.

---

## Coverage Gaps & Ambiguities
- `scripts/migrate-mongo-to-postgres.py`: Legacy migration script with no active callers; assigned as an ad-hoc part if review is requested, otherwise excluded from core service review.
