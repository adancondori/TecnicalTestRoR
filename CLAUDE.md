# CLAUDE.md - Payment Gateway Provider

## Critical Rules

1. **TDD First**: Always write tests BEFORE implementation. Red -> Green -> Refactor. No code without a failing spec first.
2. **SOLID Principles**: Every class, service, and module must follow Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, and Dependency Inversion. Prefer composition over inheritance.
3. **Never commit or push** without explicit user permission.
4. **Never mention AI** in commit messages, code comments, or PR descriptions.
5. **Never commit secrets** (.env, credentials, API keys, tokens).
6. **Use `Time.current`**, never `Time.now`.
7. **Financial operations** must use `ActiveRecord::Base.transaction`.
8. **Backward compatibility**: Never break the existing API contract.

## Project Overview

Mini Payment Gateway Provider. Merchants connect via REST API to tokenize cards, process payments (Card, eWallet, QR), handle refunds, voids, and receive webhook notifications.

**Stack**: Ruby 3.2.0 / Rails 7.0.4 / MySQL 8.0 / Docker

## Running the App

```bash
docker network create networks_default   # first time only
docker compose build && docker compose up -d
docker compose exec app rails db:create db:migrate db:seed
```

- App: `http://localhost:3001`
- DB: port `3307`
- Frontend (Vite): port `5173`
- Nginx: port `8000`

## Running Tests

```bash
docker compose exec app bundle exec rspec                          # full suite (132 specs)
docker compose exec app bundle exec rspec spec/path/to_spec.rb    # single file
docker compose exec app bundle exec rspec spec/path/to_spec.rb:42 # single example
```

Test DB is `technical_test`, separate from dev `technical_development`. Docker compose env vars override `.env`; restart container after changes.

## Architecture

```
Merchant App
     |
     | HTTP Basic Auth (api_key:api_secret)
     v
┌──────────────────────────────────────────┐
│              API (Rails)                 │
│  POST /api/v1/payment_methods           │ Card Tokenization + 3DS
│  POST /api/v1/payment_requests          │ Payments (Card/eWallet/QR)
│  POST /api/v1/.../capture               │ Manual Capture
│  POST /api/v1/.../void                  │ Void
│  POST /api/v1/.../refunds               │ Refunds
│  POST /api/v1/qr_payments/:id/simulate  │ QR Simulation
└──────────────┬───────────────────────────┘
               |
    ┌──────────┼──────────┐
    v          v          v
 3DS Page   eWallet    WebhookDeliveryJob
 (HTML)     Sim Page   (HMAC-SHA256)
```

## Domain Models (6)

| Model | Prefix | Key Associations |
|-------|--------|------------------|
| `Merchant` | `merch-` | has_many: payment_methods, payment_requests, refunds, webhook_events |
| `PaymentMethod` | `pm-` | belongs_to: merchant; has_many: three_d_secure_challenges, payment_requests |
| `PaymentRequest` | `pr-` | belongs_to: merchant, payment_method (optional); has_many: refunds |
| `Refund` | `rf-` | belongs_to: payment_request, merchant |
| `ThreeDSecureChallenge` | `3ds-` | belongs_to: payment_method; optional: payment_request_id |
| `WebhookEvent` | `we-` | belongs_to: merchant |

### ID Generation (HasPrefixedId concern)
All models use `id: false` (string PKs). `before_create` generates `"prefix-#{SecureRandom.uuid}"` if `id.blank?`.

### State Machine (HasStateMachine concern)
Only `PaymentRequest` uses it. ~20 lines. Defines `allowed_transitions` hash, `can_transition_to?`, `transition_to!`. Raises `PaymentGateway::InvalidState` on invalid transitions.

```
PENDING -> REQUIRES_ACTION | AUTHORIZED | FAILED
REQUIRES_ACTION -> AUTHORIZED | FAILED
AUTHORIZED -> CAPTURED | VOIDED
CAPTURED -> SUCCEEDED | REFUNDED
SUCCEEDED -> REFUNDED
```

## Controllers (10)

### API Controllers (`Api::V1::`)
- **BaseController** - inherits `ActionController::API`, includes `MerchantAuthentication`, rescues all custom errors
- **PaymentMethodsController** - CRUD + tokenization, includes `Idempotent`
- **PaymentRequestsController** - CRUD + capture + void, includes `Idempotent`, filters (status, reference_id, date range)
- **QrPaymentsController** - simulate action
- **RefundsController** - CRUD

### Server-Rendered
- **ThreeDSecureController** - challenge form + OTP verify (hardcoded "1234")
- **EwalletSimulationController** - pay page + confirm action
- **MerchantsController** - dashboard CRUD + regenerate_webhook_secret
- **Merchants::PaymentRequestsController** - nested show/capture/void
- **Merchants::RefundsController** - nested create

### Concerns
- **MerchantAuthentication**: HTTP Basic Auth, constant-time compare via `ActiveSupport::SecurityUtils.secure_compare`, rejects SUSPENDED merchants
- **Idempotent**: `X-Request-ID` header dedup, raises `PaymentGateway::DuplicateError` (409), saves via `update_column`

## Services (9) - Business Logic Lives Here

| Service | Responsibility |
|---------|---------------|
| `TokenizationService` | Card/eWallet/QR tokenization, 3DS challenge creation |
| `CardValidationService` | Luhn check, network detection, 3DS test card rules, masking, fingerprint |
| `Payments::CreateService` | Payment creation (card/eWallet/QR), inline tokenization, auto-capture |
| `Payments::CaptureService` | AUTHORIZED+MANUAL -> CAPTURED -> SUCCEEDED |
| `Payments::VoidService` | AUTHORIZED -> VOIDED |
| `Payments::RefundService` | Full/partial refund with transaction, updates refunded_amount |
| `Payments::QrSimulateService` | REQUIRES_ACTION -> AUTHORIZED -> auto-capture if AUTOMATIC |
| `Payments::AfterThreeDsService` | Post-3DS flow for payment requests |
| `ThreeDSecure::VerificationService` | Challenge result handling, delegates to AfterThreeDsService |
| `WebhookService` | Creates WebhookEvent (PENDING) + executes WebhookDeliveryJob |

**Pattern**: Thin controllers delegate ALL business logic to services. Each service has a single responsibility.

## Jobs (1)

| Job | Queue | Behavior |
|-----|-------|----------|
| `WebhookDeliveryJob` | `:webhooks` | HTTP POST with HMAC-SHA256, 1 attempt, `perform_now` for ordering guarantee |

ActiveJob adapter: `:async` (application.rb), `:inline` (test.rb).

## Error Hierarchy

All extend `PaymentGateway::BaseError`. Each has `status` and `error_code`. `to_h` returns `{ error: { code, message } }`.

| Error | HTTP Status | Code |
|-------|-------------|------|
| `AuthenticationFailed` | 401 | AUTHENTICATION_FAILED |
| `MerchantSuspended` | 403 | MERCHANT_SUSPENDED |
| `NotFound` | 404 | NOT_FOUND |
| `DuplicateError` | 409 | DUPLICATE_ERROR |
| `InvalidState` | 409 | INVALID_STATE |
| `ValidationError` | 422 | VALIDATION_ERROR |

## Webhook Events

Delivered via `WebhookDeliveryJob` with HMAC-SHA256 signature (`X-Webhook-Signature`).

**Event types**: `payment.authorized`, `payment.captured`, `payment.succeeded`, `payment.failed`, `payment.requires_action`, `void.succeeded`, `refund.succeeded`, `payment_method.auth_completed`, `payment_method.auth_failed`

## Payment Flows

1. **Card (no 3DS)**: PENDING -> AUTHORIZED -> CAPTURED -> SUCCEEDED
2. **Card (3DS)**: PENDING -> REQUIRES_ACTION -> [OTP challenge] -> AUTHORIZED -> CAPTURED -> SUCCEEDED
3. **eWallet**: PENDING -> REQUIRES_ACTION -> [user confirms] -> AUTHORIZED -> CAPTURED -> SUCCEEDED
4. **QR Code**: PENDING -> REQUIRES_ACTION -> [simulate scan] -> AUTHORIZED -> CAPTURED -> SUCCEEDED
5. **Manual Capture**: AUTHORIZED -> [capture] -> CAPTURED -> SUCCEEDED
6. **Void**: AUTHORIZED -> VOIDED
7. **Refund**: SUCCEEDED/CAPTURED -> REFUNDED (partial or full)

## Test Cards

| Number | Network | 3DS | Result |
|--------|---------|-----|--------|
| `4000000000001000` | VISA | No | Direct success |
| `5200000000001005` | Mastercard | No | Direct success |
| `4000000000001091` | VISA | Yes | OTP 1234 -> Success |
| `5200000000001096` | Mastercard | Yes | OTP 1234 -> Success |
| `4000000000001109` | VISA | Yes | Always fails |

## Seed Merchants

| Merchant | API Key | API Secret | Status |
|----------|---------|------------|--------|
| Acme Corp | `pk_test_acme001` | `sk_test_acme001_secret` | ACTIVE |
| Globex Corp | `pk_test_globex002` | `sk_test_globex002_secret` | ACTIVE |
| Initech | `pk_test_initech003` | `sk_test_initech003_secret` | ACTIVE |
| Umbrella Corp | `pk_test_umbrella004` | `sk_test_umbrella004_secret` | ACTIVE |
| Suspended Inc | `pk_test_susp005` | `sk_test_susp005_secret` | SUSPENDED |

## Testing Conventions (TDD)

### Workflow
1. Write a failing spec first (Red)
2. Write the minimum code to make it pass (Green)
3. Refactor while keeping tests green (Refactor)

### Factory Usage
- `build()` — DEFAULT for validations/unit tests (no DB hit)
- `build_stubbed()` — when code needs `id` or `persisted?`
- `create()` — ONLY for scopes, queries, callbacks, integration tests

### Key Patterns
- **MySQL utf8mb4_unicode_ci** is case-insensitive: use `.case_insensitive` in shoulda-matchers uniqueness tests
- **WebMock** blocks all external HTTP; global webhook stub in `spec/support/webhook_stubs.rb`
- **ActiveJob `:inline`** in test env: jobs execute synchronously
- **Transactional fixtures** enabled: each test runs in a rolled-back transaction
- For `have_enqueued_job` matcher: temporarily switch to `:test` adapter with `around` block

### Forbidden in Tests
- `allow_any_instance_of`
- Hardcoded IDs in factories
- `Time.now` (use `Time.current` + `freeze_time`)
- Sleeping or arbitrary waits

### Spec Organization
```
spec/
├── factories/           # FactoryBot definitions
├── jobs/                # Job specs
├── models/              # Model validations, associations, state machine
├── services/            # Service unit tests
├── requests/api/v1/     # Request/integration specs
├── swagger/api/v1/      # Swagger/OpenAPI generation specs
└── support/             # Shared helpers (auth_helpers, webhook_stubs)
```

## SOLID Guidelines

### Single Responsibility (S)
- Controllers: only parse params, call service, render response
- Services: one public method (`call` or domain-specific like `deliver!`), one responsibility
- Models: validations, associations, scopes. No business logic beyond state machine transitions.
- Jobs: only orchestrate the execution of a deliverable unit of work

### Open/Closed (O)
- Add new payment types by creating new service classes, not by modifying existing ones
- Error hierarchy: extend `PaymentGateway::BaseError` for new error types
- New webhook events: add event type string, no structural change needed

### Liskov Substitution (L)
- All `PaymentGateway::*Error` classes are interchangeable where `BaseError` is expected
- All services follow the same pattern: initialize with dependencies, expose a public method

### Interface Segregation (I)
- Concerns (`HasPrefixedId`, `HasStateMachine`, `MerchantAuthentication`, `Idempotent`) are small and focused
- Controllers include only the concerns they need

### Dependency Inversion (D)
- Services receive dependencies via constructor (`merchant:`, `payment_request:`)
- `WebhookService` delegates to `WebhookDeliveryJob` — delivery mechanism is decoupled from event creation
- Controllers depend on service interfaces, not implementation details

## Project Structure

```
backend/
├── app/
│   ├── controllers/
│   │   ├── api/v1/                  # API controllers (5)
│   │   │   ├── base_controller.rb
│   │   │   ├── payment_methods_controller.rb
│   │   │   ├── payment_requests_controller.rb
│   │   │   ├── refunds_controller.rb
│   │   │   └── qr_payments_controller.rb
│   │   ├── concerns/                # Auth + Idempotency
│   │   │   ├── merchant_authentication.rb
│   │   │   └── idempotent.rb
│   │   ├── three_d_secure_controller.rb
│   │   ├── ewallet_simulation_controller.rb
│   │   ├── merchants_controller.rb
│   │   └── merchants/               # Dashboard nested controllers
│   ├── errors/payment_gateway/      # 7 error classes
│   ├── jobs/
│   │   └── webhook_delivery_job.rb
│   ├── models/
│   │   ├── concerns/                # HasPrefixedId, HasStateMachine
│   │   ├── merchant.rb
│   │   ├── payment_method.rb
│   │   ├── payment_request.rb
│   │   ├── refund.rb
│   │   ├── three_d_secure_challenge.rb
│   │   └── webhook_event.rb
│   ├── services/                    # 9 service classes
│   │   ├── card_validation_service.rb
│   │   ├── tokenization_service.rb
│   │   ├── webhook_service.rb
│   │   └── payments/                # 6 payment services
│   └── views/                       # 3DS, eWallet, Merchant dashboard
├── config/
│   ├── routes.rb
│   ├── database.yml
│   └── environments/
├── db/
│   ├── migrate/                     # 7 migrations (string PKs)
│   ├── schema.rb
│   └── seeds.rb
├── spec/                            # 132 specs
│   ├── factories/
│   ├── jobs/
│   ├── models/
│   ├── services/
│   ├── requests/api/v1/
│   ├── swagger/api/v1/
│   └── support/
├── swagger/v1/swagger.yaml
└── postman/                         # Postman collection + environment
```

## Design Decisions

1. **Amounts in cents** (integer) — avoids floating point issues
2. **String PKs with prefixes** (`pm-`, `pr-`, `tok-`, `rf-`, `we-`) — resource type visible in any ID
3. **Hand-rolled state machine** (~20 lines) — no external gem, SOLID compliant
4. **Service objects** — thin controllers, all business logic in services (SRP)
5. **Webhook delivery via ActiveJob** — `WebhookDeliveryJob` decouples delivery from event creation; `perform_now` guarantees ordering
6. **`type_name` column** — avoids STI collision with Rails `type` column
7. **HTTP Basic Auth** — simple, standard, works with curl and Postman
8. **Custom error hierarchy** — structured JSON errors, consistent across all endpoints (OCP)
9. **Idempotency via X-Request-ID** — prevents duplicate operations at the API layer
10. **Concerns for cross-cutting** — HasPrefixedId, HasStateMachine, MerchantAuthentication, Idempotent (ISP)
