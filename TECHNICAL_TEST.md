# Technical Test: Payment Gateway Integration

## Position: Senior Payment Gateway Engineer

### Context

You have been given access to a **Payment Gateway Provider API** (similar to Xendit, Stripe, or Adyen). Your task is to build a **merchant backend service** that integrates with this gateway to accept payments, handle asynchronous events, and manage the full payment lifecycle.

The gateway is already running and fully functional. You will consume its API as a merchant would in a real-world scenario.

### What We Evaluate

| Criteria | What we look for |
|----------|-----------------|
| **Code quality** | SOLID principles, clean architecture, separation of concerns, readability |
| **Testing** | TDD approach, meaningful coverage, edge cases, tests that document behavior |
| **Correct implementation** | Flows work end-to-end, state transitions are handled properly |
| **Error handling & resilience** | Graceful degradation, idempotency, signature verification |
| **Decision making** | Which challenges you choose, how you prioritize, trade-offs you explain |

> We strongly value **TDD** and **SOLID principles**. We expect to see tests written before or alongside implementation, not as an afterthought. A well-tested partial solution will always score higher than a complete implementation with no tests.

---

## Setup

### 1. Start the Payment Gateway

```bash
# Create external network (first time only)
docker network create networks_default

# Build and start
docker compose build
docker compose up -d

# Wait ~10s for MySQL, then setup database
docker compose exec app rails db:create db:migrate db:seed

# Verify it works (132 specs should pass)
docker compose exec app bundle exec rspec
```

The gateway API is available at `http://localhost:3001`.

### 2. Your Credentials

Use any of these test merchants:

| Merchant | API Key | API Secret |
|----------|---------|------------|
| Acme Corp | `pk_test_acme001` | `sk_test_acme001_secret` |
| Globex Corp | `pk_test_globex002` | `sk_test_globex002_secret` |
| Initech | `pk_test_initech003` | `sk_test_initech003_secret` |

**Authentication**: HTTP Basic Auth. The `api_key` is the username, the `api_secret` is the password.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret http://localhost:3001/api/v1/payment_requests
```

### 3. Test Cards

| Card Number | Network | 3D Secure | Behavior |
|-------------|---------|-----------|----------|
| `4000000000001000` | VISA | No | Direct success |
| `5200000000001005` | Mastercard | No | Direct success |
| `4000000000001091` | VISA | Yes | OTP challenge, code: `1234` |
| `5200000000001096` | Mastercard | Yes | OTP challenge, code: `1234` |
| `4000000000001109` | VISA | Yes | Always fails |

### 4. Important Notes

- Amounts are in **cents** (integer). `$150.00` = `15000`.
- All errors follow the format: `{ "error": { "code": "...", "message": "..." } }`
- The Swagger UI is at `http://localhost:3001/api-docs`
- A Postman collection is available in `backend/postman/`

---

## The Challenge

This test has one **Core** requirement and a set of **Extensions** you can choose from. The Core establishes a baseline. The Extensions are where you demonstrate your strengths.

**You choose** which extensions to tackle and in what order. There is no requirement to complete all of them. We care about **how** you solve what you choose, not **how many** you complete.

You may use any language/framework you prefer.

---

## Core: Direct Card Payments (Required)

**Goal**: Build a service that accepts card payments through the gateway and handles the result.

### Requirements

1. **Create a direct card payment**
   - `POST /api/v1/payment_requests` with card details inline
   - Use a non-3DS test card (`4000000000001000`)
   - Verify the payment reaches `SUCCEEDED` status

2. **Retrieve a payment by ID**
   - `GET /api/v1/payment_requests/:id`

3. **List payments with filters**
   - `GET /api/v1/payment_requests?status=succeeded&from_date=2026-01-01`

4. **Handle errors gracefully**
   - Invalid credentials (401)
   - Suspended merchant (403)
   - Resource not found (404)
   - Validation errors (422)

### API Reference

```bash
# Create a direct card payment
POST /api/v1/payment_requests
{
  "reference_id": "order-001",
  "amount": 50000,
  "currency": "USD",
  "card": {
    "card_number": "4000000000001000",
    "expiry_month": "12",
    "expiry_year": "2028",
    "cvv": "123",
    "cardholder_name": "John Doe"
  }
}
# Expected: status "SUCCEEDED", captured_amount: 50000

# Get payment
GET /api/v1/payment_requests/:id

# List payments
GET /api/v1/payment_requests?status=succeeded
```

### Deliverables

- [ ] Service/module that creates a card payment and returns the result
- [ ] Error handling for all HTTP error codes
- [ ] Tests for success and error scenarios

---

## Extensions: Choose Your Path

Below are independent challenges organized by domain. Pick the ones that interest you most, that best demonstrate your skills, or that you consider most critical for a production payment system.

Each extension lists what we look for when reviewing it.

---

### EXT-1: Card Tokenization

Tokenize cards so customers don't have to re-enter card details on every purchase.

**What to build**:
- `POST /api/v1/payment_methods` to tokenize a card
- Store the returned `payment_method_id`
- Pay with the token: `POST /api/v1/payment_requests` using `payment_method_id` instead of raw card data

**API Reference**:
```bash
# Tokenize
POST /api/v1/payment_methods
{ "type": "CARD", "card": { "card_number": "4000000000001000", "expiry_month": "12", "expiry_year": "2028", "cvv": "123", "cardholder_name": "John Doe" } }
# Response: { "data": { "id": "pm-...", "status": "ACTIVE", "card": { "token_id": "tok-...", ... } } }

# Pay with token
POST /api/v1/payment_requests
{ "payment_method_id": "pm-...", "reference_id": "order-002", "amount": 30000, "currency": "USD" }
```

**We look for**: clean separation between tokenization and payment logic, token storage design.

---

### EXT-2: 3D Secure Authentication

Handle cards that require 3D Secure (OTP challenge) before the payment can proceed.

**What to build**:
- Detect when a card requires 3DS (response status: `PENDING_AUTHENTICATION` or `REQUIRES_ACTION`, with `actions` array)
- Handle the challenge URL (open in browser, user enters OTP `1234`)
- Poll or listen for the payment to complete after authentication
- Handle authentication failure (card `4000000000001109`)

**Flows**:

*Standalone tokenization with 3DS*:
```bash
POST /api/v1/payment_methods
{ "type": "CARD", "card": { "card_number": "4000000000001091", ... } }
# Response: status "PENDING_AUTHENTICATION", actions: [{ "type": "AUTH", "url": "http://localhost:3001/3ds/challenge/pm-...", "method": "GET" }]
# -> Open URL, enter OTP 1234 -> payment_method becomes ACTIVE
```

*Direct card payment with 3DS*:
```bash
POST /api/v1/payment_requests
{ "reference_id": "order-003", "amount": 25000, "currency": "USD", "card": { "card_number": "4000000000001091", ... } }
# Response: status "REQUIRES_ACTION", actions: [{ "type": "AUTH", "url": "...", "method": "GET" }]
# -> Open URL, enter OTP 1234 -> payment completes: AUTHORIZED -> CAPTURED -> SUCCEEDED
```

**We look for**: async flow handling, status polling strategy, failure scenario coverage in tests.

---

### EXT-3: Alternative Payment Methods (eWallet & QR Code)

Support payment methods beyond cards.

**eWallet**:
```bash
POST /api/v1/payment_requests
{ "reference_id": "order-004", "amount": 15000, "currency": "USD", "ewallet": { "channel_code": "OVO" } }
# Response: status "REQUIRES_ACTION", ewallet_url: "http://localhost:3001/ewallet/pay/pr-..."
# -> Redirect customer to ewallet_url -> user clicks "Confirm" -> payment completes
```

**QR Code**:
```bash
POST /api/v1/payment_requests
{ "reference_id": "order-005", "amount": 20000, "currency": "USD", "qr_code": { "channel_code": "QRIS" } }
# Response: status "REQUIRES_ACTION", qr_string: "QR-pr-...-a1b2c3d4"
# -> Display qr_string as QR code -> simulate scan:
POST /api/v1/qr_payments/pr-xxx/simulate
```

**We look for**: polymorphic payment handling (how you abstract different payment types), shared vs. specific logic.

---

### EXT-4: Webhook Receiver & Signature Verification

Listen for real-time payment events instead of polling.

**What to build**:
- An HTTP endpoint that receives POST requests from the gateway
- **Verify HMAC-SHA256 signatures** — reject requests with invalid signatures
- Update your local payment state based on webhook events

**Webhook format**:
```
POST <your_callback_url>
Content-Type: application/json
X-Webhook-Signature: <HMAC-SHA256 hex digest of body using webhook_secret>
X-Webhook-Event: payment.succeeded
X-Webhook-Id: we-...

{
  "event": "payment.succeeded",
  "data": { "id": "pr-...", "amount": 50000, "status": "SUCCEEDED", ... },
  "created_at": "2026-03-02T04:14:43Z"
}
```

**Events**:

| Event | When |
|-------|------|
| `payment.authorized` | Payment authorized |
| `payment.captured` | Payment captured |
| `payment.succeeded` | Payment completed |
| `payment.failed` | Payment failed |
| `payment.requires_action` | Customer action needed |
| `payment_method.auth_completed` | 3DS succeeded |
| `payment_method.auth_failed` | 3DS failed |
| `void.succeeded` | Void completed |
| `refund.succeeded` | Refund completed |

**Signature verification**:
```
expected = HMAC-SHA256(webhook_secret, raw_request_body)
valid = constant_time_compare(expected, X-Webhook-Signature)
```

> Use constant-time comparison to prevent timing attacks.

Configure your `callback_url` through the Merchant Dashboard at `http://localhost:3001/merchants`.

**We look for**: security-first mindset (signature verification, constant-time compare), idempotent event processing (handling duplicate deliveries), state reconciliation.

---

### EXT-5: Idempotency

Prevent duplicate payments caused by network retries or user double-clicks.

**What to build**:
- Generate and send `X-Request-ID` header on all creation requests
- Handle `409 DUPLICATE_ERROR` responses gracefully
- Ensure your system never creates duplicate payments

```bash
# First call -> 201 Created
POST /api/v1/payment_requests
X-Request-ID: unique-id-123
{ ... }

# Second call, same X-Request-ID -> 409 Conflict
{ "error": { "code": "DUPLICATE_ERROR", "message": "Duplicate request. Existing resource: pr-..." } }
```

Idempotency applies to `POST /api/v1/payment_methods` and `POST /api/v1/payment_requests`.

**We look for**: key generation strategy, how you handle the 409 response (return existing resource vs. error), test coverage for race conditions.

---

### EXT-6: Manual Capture & Void

Separate authorization from capture. Useful for marketplaces, pre-orders, or hold-and-charge scenarios.

**Manual capture** (two-step):
```bash
# Step 1: Authorize (funds reserved, not charged)
POST /api/v1/payment_requests
{ "payment_method_id": "pm-...", "reference_id": "order-mc", "amount": 75000, "currency": "USD", "capture_method": "MANUAL" }
# Response: status "AUTHORIZED"

# Step 2: Capture (charge the customer)
POST /api/v1/payment_requests/pr-xxx/capture
{ "amount": 75000 }
# Response: status "SUCCEEDED"
# Note: capture amount can be <= authorized amount (partial capture)
```

**Void** (cancel before capture):
```bash
POST /api/v1/payment_requests/pr-xxx/void
# Response: status "VOIDED"
# Only works on AUTHORIZED payments
```

**We look for**: state machine awareness (what transitions are valid), edge case handling (void after capture, capture after void, amount validation).

---

### EXT-7: Refunds (Full & Partial)

Return money to customers after a successful payment.

```bash
# Full refund
POST /api/v1/payment_requests/pr-xxx/refunds
{ "amount": 50000, "reason": "Customer request" }

# Partial refund (multiple allowed)
POST /api/v1/payment_requests/pr-xxx/refunds
{ "amount": 20000, "reason": "Partial return" }

# List all refunds
GET /api/v1/refunds

# Get specific refund
GET /api/v1/refunds/rf-xxx
```

- Works on `SUCCEEDED` or `CAPTURED` payments
- Multiple partial refunds allowed until `refunded_amount >= captured_amount`
- Payment transitions to `REFUNDED` when fully refunded

**We look for**: transaction safety (what if two partial refunds race?), boundary validation (refund > available amount), proper use of the state machine.

---

## Payment State Machine Reference

```
PENDING ──────► REQUIRES_ACTION ──────► AUTHORIZED ──────► CAPTURED ──────► SUCCEEDED
   │                   │                    │                   │                │
   │                   ▼                    ▼                   ▼                ▼
   └──────────────► FAILED              VOIDED             SUCCEEDED        REFUNDED
                                                               │
                                                               ▼
                                                           REFUNDED
```

---

## Submission

### What to deliver

1. **A working codebase** in any language/framework you choose
2. **A README.md** with:
   - How to set up and run your project
   - Which extensions you chose and **why**
   - Architecture decisions and trade-offs
   - Anything you would do differently with more time
3. **A test suite** that demonstrates your approach
4. **Git history** with meaningful commits that show your development process

### How we review

- We read your code in detail. We value clarity and intention over cleverness.
- We run your tests. They should pass with the setup described in your README.
- We look at your git history. Small, focused commits tell us how you think.
- We pay attention to what you **chose** to build and why. Your priorities reveal your experience.
- A well-tested solution with 3 extensions will score higher than a poorly-tested one with all 7.

---

Good luck. We look forward to reviewing your solution.
