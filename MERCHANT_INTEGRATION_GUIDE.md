# Merchant Integration Guide - Payment Gateway Provider

## Introduction

This guide is intended for **Senior Payment Gateway Engineers** evaluating or integrating with our Payment Gateway Provider API.

The integration is divided into three tiers. Each tier builds upon the previous one, progressively covering more payment methods, security features, and operational capabilities.

| Tier | Scope | Expected For |
|------|-------|--------------|
| **Basic** | Direct card payments, listing transactions | MVP / Quick checkout |
| **Intermediate** | Tokenized cards, 3D Secure, eWallet, QR Code | Production-grade payment flow |
| **Complete** | Webhooks, idempotency, voids, refunds, manual capture | Full operational integration |

---

## Prerequisites

### Base URL

```
http://localhost:3001
```

### Authentication

All API calls use **HTTP Basic Auth**. Your `api_key` is the username and `api_secret` is the password.

```bash
curl -u <api_key>:<api_secret> ...
```

### Test Credentials

| Merchant | API Key | API Secret |
|----------|---------|------------|
| Acme Corp | `pk_test_acme001` | `sk_test_acme001_secret` |
| Globex Corp | `pk_test_globex002` | `sk_test_globex002_secret` |
| Initech | `pk_test_initech003` | `sk_test_initech003_secret` |
| Umbrella Corp | `pk_test_umbrella004` | `sk_test_umbrella004_secret` |

> `Suspended Inc` (`pk_test_susp005`) is a suspended merchant — use it to test `403 MERCHANT_SUSPENDED` errors.

### Test Cards

| Card Number | Network | 3D Secure | Behavior |
|-------------|---------|-----------|----------|
| `4000000000001000` | VISA | No | Direct success |
| `5200000000001005` | Mastercard | No | Direct success |
| `4000000000001091` | VISA | Yes | Challenge required, OTP: `1234` |
| `5200000000001096` | Mastercard | Yes | Challenge required, OTP: `1234` |
| `4000000000001109` | VISA | Yes | Challenge always fails |

### Amounts

All amounts are in **cents** (integer). Example: `$150.00` = `15000`.

### Error Format

All errors follow a consistent structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Description of the problem"
  }
}
```

| HTTP Status | Code | Meaning |
|-------------|------|---------|
| 401 | `AUTHENTICATION_FAILED` | Invalid api_key or api_secret |
| 403 | `MERCHANT_SUSPENDED` | Merchant account is suspended |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `DUPLICATE_ERROR` | Duplicate `X-Request-ID` |
| 409 | `INVALID_STATE` | Invalid state transition |
| 422 | `VALIDATION_ERROR` | Invalid parameters |

---

## Tier 1: Basic Integration

**Goal**: Accept a card payment and verify the result.

### 1.1 Create a Direct Card Payment

Send card details directly. The gateway tokenizes the card inline, authorizes, captures, and settles the payment in one step.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
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
  }'
```

**Expected response** (HTTP 201):
```json
{
  "data": {
    "id": "pr-...",
    "reference_id": "order-001",
    "amount": 50000,
    "currency": "USD",
    "status": "SUCCEEDED",
    "capture_method": "AUTOMATIC",
    "payment_type": "CARD",
    "payment_method_id": "pm-...",
    "captured_amount": 50000,
    "refunded_amount": 0,
    "created_at": "2026-03-02T...",
    "updated_at": "2026-03-02T..."
  }
}
```

> With a non-3DS card and `capture_method: "AUTOMATIC"` (default), the payment goes through the full lifecycle: `PENDING -> AUTHORIZED -> CAPTURED -> SUCCEEDED`.

### 1.2 Get a Payment by ID

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_requests/pr-xxx
```

### 1.3 List Payments

```bash
# All payments
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_requests

# With filters
curl -u pk_test_acme001:sk_test_acme001_secret \
  "http://localhost:3001/api/v1/payment_requests?status=succeeded&from_date=2026-01-01&to_date=2026-12-31"
```

**Available filters**: `status`, `reference_id`, `from_date`, `to_date`

### 1.4 Verify Authentication

Test your credentials are correct:

```bash
# Valid credentials -> 200 with data
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_requests

# Invalid credentials -> 401
curl -u wrong_key:wrong_secret \
  http://localhost:3001/api/v1/payment_requests

# Suspended merchant -> 403
curl -u pk_test_susp005:sk_test_susp005_secret \
  http://localhost:3001/api/v1/payment_requests
```

### Basic Integration Checklist

- [ ] Authenticate with HTTP Basic Auth
- [ ] Create a direct card payment (non-3DS card)
- [ ] Retrieve a payment by ID
- [ ] List payments with filters
- [ ] Handle 401, 403, 404, 422 error responses

---

## Tier 2: Intermediate Integration

**Goal**: Tokenize cards for reuse, handle 3D Secure challenges, and accept eWallet and QR Code payments.

### 2.1 Card Tokenization

Tokenize a card to get a reusable `payment_method_id`.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_methods \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CARD",
    "card": {
      "card_number": "4000000000001000",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "John Doe"
    }
  }'
```

**Response** (non-3DS card):
```json
{
  "data": {
    "id": "pm-...",
    "type": "CARD",
    "status": "ACTIVE",
    "reusability": "MULTIPLE_USE",
    "card": {
      "token_id": "tok-...",
      "masked_card_number": "****1000",
      "card_network": "VISA",
      "card_type": "CREDIT",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cardholder_name": "John Doe",
      "fingerprint": "a1b2c3d4e5f6..."
    }
  }
}
```

### 2.2 Pay with a Tokenized Card

Use the `payment_method_id` from tokenization. No card details needed.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "payment_method_id": "pm-xxx",
    "reference_id": "order-002",
    "amount": 30000,
    "currency": "USD"
  }'
```

### 2.3 Card Tokenization with 3D Secure

When using a 3DS-enabled test card, the payment method requires authentication before it can be used.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_methods \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CARD",
    "card": {
      "card_number": "4000000000001091",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "Jane Doe"
    }
  }'
```

**Response** (3DS required):
```json
{
  "data": {
    "id": "pm-...",
    "type": "CARD",
    "status": "PENDING_AUTHENTICATION",
    "actions": [
      {
        "type": "AUTH",
        "url": "http://localhost:3001/3ds/challenge/pm-...",
        "method": "GET"
      }
    ]
  }
}
```

**Next step**: Open the `url` from `actions` in a browser. Enter OTP `1234` and submit. On success the payment method transitions to `ACTIVE`.

### 2.4 Direct Card Payment with 3D Secure

You can also send a 3DS card directly in a payment request (inline tokenization + 3DS):

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-003",
    "amount": 25000,
    "currency": "USD",
    "card": {
      "card_number": "4000000000001091",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "Jane Doe"
    }
  }'
```

**Response**:
```json
{
  "data": {
    "id": "pr-...",
    "status": "REQUIRES_ACTION",
    "actions": [
      {
        "type": "AUTH",
        "url": "http://localhost:3001/3ds/challenge/pm-...",
        "method": "GET"
      }
    ]
  }
}
```

Open the `url` in a browser, enter OTP `1234`. On success the payment automatically completes: `REQUIRES_ACTION -> AUTHORIZED -> CAPTURED -> SUCCEEDED`.

### 2.5 eWallet Payment

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-004",
    "amount": 15000,
    "currency": "USD",
    "ewallet": {
      "channel_code": "OVO"
    }
  }'
```

**Response**:
```json
{
  "data": {
    "id": "pr-...",
    "status": "REQUIRES_ACTION",
    "ewallet_url": "http://localhost:3001/ewallet/pay/pr-...",
    "actions": [
      {
        "type": "REDIRECT",
        "url": "http://localhost:3001/ewallet/pay/pr-...",
        "method": "GET"
      }
    ]
  }
}
```

**Next step**: Redirect the customer to `ewallet_url`. In the simulation, clicking "Confirm Payment" completes the flow: `REQUIRES_ACTION -> AUTHORIZED -> CAPTURED -> SUCCEEDED`.

### 2.6 QR Code Payment

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-005",
    "amount": 20000,
    "currency": "USD",
    "qr_code": {
      "channel_code": "QRIS"
    }
  }'
```

**Response**:
```json
{
  "data": {
    "id": "pr-...",
    "status": "REQUIRES_ACTION",
    "qr_string": "QR-pr-...-a1b2c3d4",
    "actions": [
      {
        "type": "QR_CODE",
        "qr_string": "QR-pr-...-a1b2c3d4"
      }
    ]
  }
}
```

**Next step**: Display the `qr_string` as a QR code in your app. To simulate a customer scan:

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/qr_payments/pr-xxx/simulate
```

This completes the flow: `REQUIRES_ACTION -> AUTHORIZED -> CAPTURED -> SUCCEEDED`.

### 2.7 List and Retrieve Payment Methods

```bash
# List all tokenized payment methods
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_methods

# Get a specific payment method
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_methods/pm-xxx
```

### Intermediate Integration Checklist

- [ ] Tokenize a card (non-3DS) and pay with the token
- [ ] Tokenize a card (3DS) and complete the OTP challenge
- [ ] Direct card payment with 3DS (inline tokenization + challenge)
- [ ] eWallet payment with redirect simulation
- [ ] QR Code payment with scan simulation
- [ ] Poll payment status after async actions (`GET /api/v1/payment_requests/:id`)

---

## Tier 3: Complete Integration

**Goal**: Full operational integration with webhooks, idempotency, manual capture, voids, and refunds.

### 3.1 Webhooks

When your merchant has a `callback_url` configured, the gateway sends webhook notifications for every payment lifecycle event.

#### Webhook Format

```
POST <your_callback_url>
Content-Type: application/json
X-Webhook-Signature: <HMAC-SHA256 hex digest>
X-Webhook-Event: payment.succeeded
X-Webhook-Id: we-...
```

**Body**:
```json
{
  "event": "payment.succeeded",
  "data": {
    "id": "pr-...",
    "amount": 50000,
    "status": "SUCCEEDED",
    ...
  },
  "created_at": "2026-03-02T04:14:43Z"
}
```

#### Webhook Events

| Event | When |
|-------|------|
| `payment.authorized` | Payment authorized (card approved) |
| `payment.captured` | Payment captured (funds held) |
| `payment.succeeded` | Payment completed successfully |
| `payment.failed` | Payment failed (3DS failure, etc.) |
| `payment.requires_action` | Customer action needed (3DS, eWallet redirect, QR scan) |
| `payment_method.auth_completed` | 3DS authentication succeeded |
| `payment_method.auth_failed` | 3DS authentication failed |
| `void.succeeded` | Payment voided |
| `refund.succeeded` | Refund processed |

#### Verifying Webhook Signatures

The `X-Webhook-Signature` header contains an HMAC-SHA256 hex digest of the raw request body, signed with your merchant's `webhook_secret`.

**Verification example (Ruby)**:
```ruby
expected = OpenSSL::HMAC.hexdigest("sha256", webhook_secret, raw_body)
is_valid = ActiveSupport::SecurityUtils.secure_compare(expected, received_signature)
```

**Verification example (Node.js)**:
```javascript
const crypto = require('crypto');
const expected = crypto.createHmac('sha256', webhookSecret)
                       .update(rawBody)
                       .digest('hex');
const isValid = crypto.timingSafeEqual(
  Buffer.from(expected), Buffer.from(receivedSignature)
);
```

**Verification example (Python)**:
```python
import hmac, hashlib
expected = hmac.new(
    webhook_secret.encode(), raw_body.encode(), hashlib.sha256
).hexdigest()
is_valid = hmac.compare_digest(expected, received_signature)
```

> Always use constant-time comparison to prevent timing attacks.

#### Configure Webhook URL

Set your `callback_url` through the Merchant Dashboard at `http://localhost:3001/merchants` or via the seed data.

### 3.2 Idempotency

Prevent duplicate operations by sending the `X-Request-ID` header. If the same `X-Request-ID` is sent for the same merchant, the API returns `409 DUPLICATE_ERROR`.

```bash
# First call -> 201 Created
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: unique-request-abc123" \
  -d '{
    "reference_id": "order-idem-001",
    "amount": 10000,
    "currency": "USD",
    "card": {
      "card_number": "4000000000001000",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "John Doe"
    }
  }'

# Second call with same X-Request-ID -> 409 Conflict
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: unique-request-abc123" \
  -d '{
    "reference_id": "order-idem-002",
    "amount": 20000,
    "currency": "USD",
    "card": {
      "card_number": "4000000000001000",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "John Doe"
    }
  }'
```

**409 Response**:
```json
{
  "error": {
    "code": "DUPLICATE_ERROR",
    "message": "Duplicate request. Existing resource: pr-..."
  }
}
```

Idempotency applies to `POST /api/v1/payment_methods` and `POST /api/v1/payment_requests`.

### 3.3 Manual Capture

For two-step payment flows (authorize first, capture later):

**Step 1: Authorize** (set `capture_method: "MANUAL"`):
```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "payment_method_id": "pm-xxx",
    "reference_id": "order-manual-001",
    "amount": 75000,
    "currency": "USD",
    "capture_method": "MANUAL"
  }'
```

**Response**: `status: "AUTHORIZED"` (funds reserved, not yet captured).

**Step 2: Capture** (full or partial amount):
```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/capture \
  -H "Content-Type: application/json" \
  -d '{ "amount": 75000 }'
```

After capture: `AUTHORIZED -> CAPTURED -> SUCCEEDED`.

> Capture amount cannot exceed the authorized amount.

### 3.4 Void

Cancel an authorized payment before it has been captured. Only works on `AUTHORIZED` payments.

```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/void
```

**Response**: `status: "VOIDED"`. Triggers webhook `void.succeeded`.

> You cannot void a payment that has already been captured. Use a refund instead.

### 3.5 Refunds

Refund a completed payment (full or partial). Works on `SUCCEEDED` or `CAPTURED` payments.

**Full refund**:
```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/refunds \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50000,
    "reason": "Customer request"
  }'
```

**Partial refund** (you can issue multiple partial refunds until the total matches `captured_amount`):
```bash
# First partial refund
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/refunds \
  -H "Content-Type: application/json" \
  -d '{ "amount": 20000, "reason": "Partial return" }'

# Second partial refund
curl -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/refunds \
  -H "Content-Type: application/json" \
  -d '{ "amount": 30000, "reason": "Remaining return" }'
```

When `refunded_amount >= captured_amount`, the payment transitions to `REFUNDED`.

**List refunds**:
```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/refunds
```

**Get a refund**:
```bash
curl -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/refunds/rf-xxx
```

### 3.6 Payment State Machine

Complete reference of all state transitions:

```
                    ┌──────────────┐
                    │   PENDING    │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              v            v            v
      ┌───────────┐  ┌──────────┐  ┌────────┐
      │ REQUIRES  │  │AUTHORIZED│  │ FAILED │
      │  ACTION   │  └────┬─────┘  └────────┘
      └─────┬─────┘       │
            │         ┌───┴────┐
            v         v        v
      ┌──────────┐ ┌──────┐ ┌───────┐
      │AUTHORIZED│ │VOIDED│ │CAPTURED│
      └────┬─────┘ └──────┘ └───┬───┘
           │                     │
      ┌────┴─────┐          ┌───┴─────┐
      v          v          v         v
  ┌──────┐ ┌────────┐ ┌─────────┐ ┌────────┐
  │VOIDED│ │CAPTURED│ │SUCCEEDED│ │REFUNDED│
  └──────┘ └───┬────┘ └────┬────┘ └────────┘
               │            │
          ┌────┴────┐  ┌────┴────┐
          v         v  v         v
     ┌─────────┐ ┌────────┐ ┌────────┐
     │SUCCEEDED│ │REFUNDED│ │REFUNDED│
     └────┬────┘ └────────┘ └────────┘
          │
     ┌────┴────┐
     v         v
 ┌────────┐
 │REFUNDED│
 └────────┘
```

### 3.7 Full End-to-End Example

A complete integration flow: tokenize a card, make a payment, partial refund, then full refund.

```bash
# 1. Tokenize a card
TOKEN_RESPONSE=$(curl -s -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_methods \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CARD",
    "card": {
      "card_number": "4000000000001000",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "John Doe"
    }
  }')
echo "$TOKEN_RESPONSE"
# Extract pm-xxx from response

# 2. Create payment with token
PAYMENT_RESPONSE=$(curl -s -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: e2e-test-001" \
  -d '{
    "payment_method_id": "<pm-xxx from step 1>",
    "reference_id": "e2e-order-001",
    "amount": 100000,
    "currency": "USD"
  }')
echo "$PAYMENT_RESPONSE"
# status: SUCCEEDED, captured_amount: 100000

# 3. Partial refund (50%)
curl -s -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/<pr-xxx>/refunds \
  -H "Content-Type: application/json" \
  -d '{ "amount": 50000, "reason": "Partial return" }'
# status: SUCCEEDED (refunded_amount: 50000)

# 4. Refund remaining
curl -s -u pk_test_acme001:sk_test_acme001_secret \
  -X POST http://localhost:3001/api/v1/payment_requests/<pr-xxx>/refunds \
  -H "Content-Type: application/json" \
  -d '{ "amount": 50000, "reason": "Full return" }'
# status: REFUNDED (refunded_amount: 100000)

# 5. Verify final state
curl -s -u pk_test_acme001:sk_test_acme001_secret \
  http://localhost:3001/api/v1/payment_requests/<pr-xxx>
# status: REFUNDED
```

### Complete Integration Checklist

- [ ] **Webhooks**: Configure `callback_url`, receive and verify HMAC signatures
- [ ] **Idempotency**: Send `X-Request-ID` on all creation requests
- [ ] **Manual Capture**: Authorize then capture (two-step flow)
- [ ] **Void**: Cancel authorized payments before capture
- [ ] **Full Refund**: Refund entire captured amount
- [ ] **Partial Refund**: Issue multiple partial refunds
- [ ] **List Refunds**: Query refund history
- [ ] **State Polling**: Poll `GET /api/v1/payment_requests/:id` for async flows
- [ ] **Error Handling**: Handle all error codes (401, 403, 404, 409, 422)
- [ ] **Webhook Events**: Handle all 9 event types

---

## API Reference Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/payment_methods` | Tokenize a card |
| `GET` | `/api/v1/payment_methods` | List payment methods |
| `GET` | `/api/v1/payment_methods/:id` | Get a payment method |
| `POST` | `/api/v1/payment_requests` | Create a payment |
| `GET` | `/api/v1/payment_requests` | List payments (filterable) |
| `GET` | `/api/v1/payment_requests/:id` | Get a payment |
| `POST` | `/api/v1/payment_requests/:id/capture` | Capture an authorized payment |
| `POST` | `/api/v1/payment_requests/:id/void` | Void an authorized payment |
| `POST` | `/api/v1/payment_requests/:id/refunds` | Refund a payment |
| `GET` | `/api/v1/refunds` | List refunds |
| `GET` | `/api/v1/refunds/:id` | Get a refund |
| `POST` | `/api/v1/qr_payments/:id/simulate` | Simulate QR code scan |

---

## Additional Resources

- **Swagger UI**: `http://localhost:3001/api-docs` (interactive API docs)
- **Merchant Dashboard**: `http://localhost:3001/merchants` (configure webhooks, view transactions)
- **Postman Collection**: Available in `backend/postman/` directory
