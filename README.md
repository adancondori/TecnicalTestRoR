# Payment Gateway Provider - Technical Test

A mini Payment Gateway Provider built with Rails 7 + MySQL 8 + Docker. Merchants connect via REST API to tokenize cards, process payments (Card, eWallet, QR), handle refunds, and voids.

## Tech Stack

- Ruby 3.2.0 / Rails 7.0
- MySQL 8.0
- Docker & Docker Compose
- RSpec (132 specs)
- Bootstrap 5 (3DS/eWallet simulation pages)

## Architecture

```
Merchant App
     |
     | HTTP Basic Auth (api_key:api_secret)
     v
┌─────────────────────────────────────┐
│          API (Rails)                │
│  POST /api/v1/payment_methods      │  Card Tokenization + 3DS
│  POST /api/v1/payment_requests     │  Payments (Card/eWallet/QR)
│  POST /api/v1/.../capture          │  Manual Capture
│  POST /api/v1/.../void             │  Void
│  POST /api/v1/.../refunds          │  Refunds
└──────────────┬──────────────────────┘
               |
    ┌──────────┼──────────┐
    v          v          v
 3DS Page   eWallet    Webhooks
 (HTML)     Sim Page   (HMAC-SHA256)
```

## Quick Start

```bash
# 1. Create external network (first time only)
docker network create networks_default

# 2. Build and start
docker compose build
docker compose up -d

# 3. Wait ~10s for MySQL, then setup database
docker compose exec app rails db:create db:migrate db:seed

# 4. Run tests
docker compose exec app bundle exec rspec
```

## Seed Merchants (Test Credentials)

| Merchant | API Key | API Secret | Status |
|----------|---------|------------|--------|
| Acme Corp | `pk_test_acme001` | `sk_test_acme001_secret` | ACTIVE |
| Globex Corp | `pk_test_globex002` | `sk_test_globex002_secret` | ACTIVE |
| Initech | `pk_test_initech003` | `sk_test_initech003_secret` | ACTIVE |
| Umbrella Corp | `pk_test_umbrella004` | `sk_test_umbrella004_secret` | ACTIVE |
| Suspended Inc | `pk_test_susp005` | `sk_test_susp005_secret` | SUSPENDED |

## Test Cards

| Card Number | Network | 3DS | Result |
|-------------|---------|-----|--------|
| `4000000000001000` | VISA | No | Direct success |
| `5200000000001005` | Mastercard | No | Direct success |
| `4000000000001091` | VISA | Yes | Challenge -> OTP 1234 -> Success |
| `5200000000001096` | Mastercard | Yes | Challenge -> OTP 1234 -> Success |
| `4000000000001109` | VISA | Yes | Challenge -> Always fails |

## API Reference

All endpoints use **HTTP Basic Auth** with `api_key` as username and `api_secret` as password.

### Payment Methods (Card Tokenization)

```bash
# Tokenize a card (no 3DS)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_methods \
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
# Response: { "data": { "id": "pm-xxx", "status": "ACTIVE", "card": { "token_id": "tok-xxx", ... } } }

# Tokenize with 3DS (requires browser OTP)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_methods \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CARD",
    "card": {
      "card_number": "4000000000001091",
      "expiry_month": "12",
      "expiry_year": "2028",
      "cvv": "123",
      "cardholder_name": "John Doe"
    }
  }'
# Response: { "data": { "status": "PENDING_AUTHENTICATION", "actions": [{ "url": "/3ds/challenge/pm-xxx" }] } }
# Open URL in browser, enter OTP: 1234

# List payment methods
curl -u pk_test_acme001:sk_test_acme001_secret http://localhost:3001/api/v1/payment_methods

# Get specific payment method
curl -u pk_test_acme001:sk_test_acme001_secret http://localhost:3001/api/v1/payment_methods/pm-xxx
```

### Payment Requests

```bash
# Pay with tokenized card (auto-capture)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "payment_method_id": "pm-xxx",
    "reference_id": "order-001",
    "amount": 50000,
    "currency": "USD"
  }'

# Pay with direct card (inline tokenization)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-002",
    "amount": 30000,
    "currency": "USD",
    "card": { "card_number": "4000000000001000", "expiry_month": "12", "expiry_year": "2028", "cvv": "123", "cardholder_name": "John" }
  }'

# Manual capture payment
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "payment_method_id": "pm-xxx",
    "reference_id": "order-003",
    "amount": 75000,
    "currency": "USD",
    "capture_method": "MANUAL"
  }'

# eWallet payment
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-004",
    "amount": 15000,
    "currency": "USD",
    "ewallet": { "channel_code": "OVO" }
  }'
# Open ewallet_url in browser to simulate payment

# QR Code payment
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -d '{
    "reference_id": "order-005",
    "amount": 20000,
    "currency": "USD",
    "qr_code": { "channel_code": "QRIS" }
  }'

# List with filters
curl -u pk_test_acme001:sk_test_acme001_secret "http://localhost:3001/api/v1/payment_requests?status=succeeded&from_date=2024-01-01"
```

### Capture / Void

```bash
# Capture (only AUTHORIZED + MANUAL)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/capture \
  -H "Content-Type: application/json" \
  -d '{ "amount": 75000 }'

# Void (only AUTHORIZED)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/void
```

### Refunds

```bash
# Create refund (full or partial)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests/pr-xxx/refunds \
  -H "Content-Type: application/json" \
  -d '{ "amount": 20000, "reason": "Customer request" }'

# List refunds
curl -u pk_test_acme001:sk_test_acme001_secret http://localhost:3001/api/v1/refunds
```

### QR Simulation

```bash
# Simulate QR code scan (transitions REQUIRES_ACTION -> SUCCEEDED)
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/qr_payments/pr-xxx/simulate
```

### Idempotency

Use `X-Request-ID` header to prevent duplicate operations:

```bash
curl -u pk_test_acme001:sk_test_acme001_secret -X POST http://localhost:3001/api/v1/payment_requests \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: unique-request-id-123" \
  -d '{ "payment_method_id": "pm-xxx", "reference_id": "order-006", "amount": 10000, "currency": "USD" }'
# Second call with same X-Request-ID returns 409 Conflict
```

## Payment State Machine

```
PENDING -> REQUIRES_ACTION  (3DS/eWallet/QR)
PENDING -> AUTHORIZED       (frictionless card)
PENDING -> FAILED

REQUIRES_ACTION -> AUTHORIZED  (after 3DS/eWallet/QR confirmation)
REQUIRES_ACTION -> FAILED

AUTHORIZED -> CAPTURED  (manual capture)
AUTHORIZED -> VOIDED    (void)

CAPTURED -> SUCCEEDED
CAPTURED -> REFUNDED

SUCCEEDED -> REFUNDED
```

## Webhooks

When a merchant has a `callback_url`, events are delivered via POST with:
- `X-Webhook-Signature`: HMAC-SHA256 of the body using `webhook_secret`
- `X-Webhook-Event`: Event type
- `X-Webhook-Id`: Unique event ID

**Events:** `payment_method.auth_completed`, `payment.authorized`, `payment.captured`, `payment.succeeded`, `payment.failed`, `refund.succeeded`, `void.succeeded`

Delivery is handled by `WebhookDeliveryJob` (ActiveJob). Single attempt per event, executed synchronously to guarantee ordering within a request.

## Project Structure

```
backend/
├── app/
│   ├── controllers/
│   │   ├── api/v1/              # API controllers
│   │   │   ├── base_controller.rb
│   │   │   ├── payment_methods_controller.rb
│   │   │   ├── payment_requests_controller.rb
│   │   │   ├── refunds_controller.rb
│   │   │   └── qr_payments_controller.rb
│   │   ├── concerns/
│   │   │   ├── merchant_authentication.rb
│   │   │   └── idempotent.rb
│   │   ├── three_d_secure_controller.rb
│   │   └── ewallet_simulation_controller.rb
│   ├── errors/payment_gateway/  # Error hierarchy
│   ├── models/
│   │   ├── merchant.rb
│   │   ├── payment_method.rb
│   │   ├── payment_request.rb
│   │   ├── refund.rb
│   │   ├── webhook_event.rb
│   │   └── concerns/
│   │       ├── has_prefixed_id.rb
│   │       └── has_state_machine.rb
│   ├── jobs/
│   │   └── webhook_delivery_job.rb
│   ├── services/
│   │   ├── card_validation_service.rb
│   │   ├── tokenization_service.rb
│   │   ├── webhook_service.rb
│   │   └── payments/
│   │       ├── create_service.rb
│   │       ├── capture_service.rb
│   │       ├── refund_service.rb
│   │       ├── void_service.rb
│   │       ├── qr_simulate_service.rb
│   │       └── after_three_ds_service.rb
│   └── views/
│       ├── three_d_secure/      # 3DS challenge pages
│       └── ewallet_simulation/  # eWallet simulation pages
├── db/migrate/                  # 7 migrations
└── spec/                        # 132 specs
    ├── factories/
    ├── jobs/
    ├── models/
    ├── services/
    └── requests/api/v1/
```

## Design Decisions

1. **Amounts in cents** (integer) - avoids floating point issues
2. **String PKs with prefixes** (`pm-`, `pr-`, `tok-`, `rf-`, `we-`) - easy to identify resource type
3. **Hand-rolled state machine** (~20 lines) - no external gem dependency
4. **Service objects** - thin controllers, all business logic in services
5. **Webhook delivery via ActiveJob** - `WebhookDeliveryJob` decouples HTTP delivery from the service layer; uses `perform_now` to guarantee event ordering within a request
6. **`type_name` column** - avoids STI collision with Rails `type` column
7. **HTTP Basic Auth** - simple, standard, works with curl
