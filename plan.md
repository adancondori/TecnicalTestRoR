# Technical Test: Payment Gateway Provider (Senior Payment Backend)


## 0. Propósito y Alcance
Construir un mini **Payment Gateway Provider** (piensa en Stripe/Xendit) donde los comercios se conectan a **nuestra** API para cobrar. El objetivo es evaluar dominio de arquitectura de pagos, seguridad y modelado de flujos, no la construcción de un PSP productivo.
- Sin certificaciones PCI-DSS reales ni conexión a redes de tarjetas; todo es simulado.
- Optimiza por corrección de flujos, diseño de APIs, limpieza de código y seguridad básica.
- Backend Rails 7 + MySQL 8; frontend mínimo (HTML/React) solo para la página de reto 3DS.

## Use TDD like principal steps
Usa started of developtment of software like KISS, SOLID, Clean Code, Unit Test, Swagger.

## 1. Entregables (Definition of Done)
- API REST JSON con endpoints descritos abajo, autenticados por merchant y cubriendo: tokenización, 3DS simulado, pagos (tokenizado y directo), eWallet/QR simulado, captura manual, refund y void.
- Página de challenge 3DS funcional (OTP fijo `1234`).
- Webhooks con firma HMAC-SHA256 y reintentos básicos.
- Seeds con **5 merchants** (pk/sk + webhook_secret conocidos) listos para probar.
- Tests mínimos (request/model) que cubran al menos: auth, tokenización feliz, 3DS fallo, pago con acción requerida, refund parcial y void inválido.
- README breve: cómo correr (docker-compose), URLs base, credenciales seed, comandos de test.

## 2. Autenticación y Control de Acceso
- **HTTP Basic Auth** en todas las rutas `/api/v1/*`.
  - username = `api_key` (prefijo `pk_test_...`)
  - password = `api_secret` (prefijo `sk_test_...`)
- Respuestas:
  - 401 `AUTHENTICATION_FAILED` si credenciales inválidas.
  - 403 `MERCHANT_SUSPENDED` si merchant en `suspended`.
- Todos los requests aceptan `X-Request-ID` (UUID) para idempotencia por par (merchant, path, method).

## 3. API Surface (resumen)
| Método | Endpoint | Uso |
|--------|----------|-----|
| POST | `/api/v1/payment_methods` | Tokenizar tarjeta (puede disparar 3DS) |
| GET | `/api/v1/payment_methods` | Listar PM del merchant |
| GET | `/api/v1/payment_methods/{id}` | Detalle PM |
| POST | `/api/v1/payment_requests` | Crear pago (tokenizado, directo, eWallet, QR) |
| POST | `/api/v1/payment_requests/{id}/capture` | Captura manual (cuando `capture_method=MANUAL`) |
| POST | `/api/v1/payment_requests/{id}/refunds` | Refund parcial o total |
| POST | `/api/v1/payment_requests/{id}/void` | Void antes de captura |
| GET | `/api/v1/payment_requests` | Listar pagos (filtros: status, fecha, reference_id) |
| GET | `/api/v1/payment_requests/{id}` | Detalle pago |
| GET | `/api/v1/refunds` | Listar refunds |
| GET | `/api/v1/refunds/{id}` | Detalle refund |
| POST | `/api/v1/qr_payments/{id}/simulate` | Simular escaneo QR |
| GET | `/3ds/challenge/{challenge_id}` | Página HTML de reto 3DS |

## 4. Tokenización de Tarjeta
**POST `/api/v1/payment_methods`**
- Valida Luhn, expiración futura, CVV formato.
- Determina si requiere 3DS según reglas de BIN (tabla abajo).
- Persiste tarjeta tokenizada: máscara `first6 + XXXXXX + last4`, fingerprint y red.
- Genera IDs: `pm-uuid`, `tok-uuid`.

**Respuesta sin 3DS**
- `status: ACTIVE`, incluye `token_id` y datos de tarjeta (enmascarados) + `fingerprint`.

**Respuesta con 3DS**
- `status: PENDING_AUTHENTICATION` + `actions[ { action: "AUTH", url: challenge_url } ]`.
- Challenge URL apunta a `/3ds/challenge/{challenge_id}`.

### Reglas 3DS (simulación)
| PAN | Network | 3DS | Escenario |
|------|---------|-----|-----------|
| 4000000000001091 | VISA | Sí | Challenge OK con OTP 1234 |
| 4000000000001000 | VISA | No | Frictionless |
| 5200000000001096 | MC | Sí | Challenge OK |
| 5200000000001005 | MC | No | Frictionless |
| 4000000000001109 | VISA | Sí | Challenge falla |

### Challenge 3DS
- Página HTML simple (Bootstrap) mostrando tarjeta enmascarada y monto.
- OTP válido fijo `1234`.
- Estados: `PENDING -> AUTHENTICATED | FAILED_AUTHENTICATION`.
- Al cerrar el flujo, dispara webhook `payment_method.auth_completed` con resultado y eci_code (05 éxito challenge, 07 fallo challenge).

## 5. Pagos
### Crear pago `POST /api/v1/payment_requests`
Campos comunes: `amount` (entero en cents), `currency`, `reference_id` (único por merchant), `capture_method` (`AUTOMATIC` por defecto, o `MANUAL`), URLs de retorno opcionales, `metadata`.

Variantes de medio de pago:
- **Tokenized card**: `payment_method_id` existente.
- **Direct card**: embebe tarjeta (mismos validations que tokenización) y opcionalmente genera `payment_method` persistido si `save_payment_method=true` (opcional bonus).
- **eWallet**: `payment_method.type=EWALLET`, channel_code p.ej. `GOPAY`, redirige a página simulada.
- **QR Code**: `payment_method.type=QR_CODE`, channel_code `QRIS`, devuelve string QR y queda `REQUIRES_ACTION` hasta simulación.

### Máquina de estados
```
PENDING
  ├─> REQUIRES_ACTION (3DS, eWallet, QR)
  │     └─> AUTHORIZED (si 3DS OK / eWallet OK / QR sim OK)
  ├─> AUTHORIZED (card frictionless)
  ├─> FAILED (cualquier error previo a captura)
AUTHORIZED
  ├─> CAPTURED (cuando capture_method=AUTOMATIC o POST /capture)
  ├─> VOIDED (POST /void antes de capturar)
CAPTURED
  ├─> SUCCEEDED (liquidado)
  ├─> REFUNDED (parcial o total)
SUCCEEDED
  ├─> REFUNDED
```
- `failure_code` poblado en fallas (usa tabla de errores estándar).

### Respuestas típicas
- Card frictionless: `status: AUTHORIZED` si `capture_method=MANUAL`, o `CAPTURED/SUCCEEDED` si automático.
- Card con 3DS: `status: REQUIRES_ACTION` + `actions` con URL 3DS.
- eWallet: `REQUIRES_ACTION` + URL simulada; al confirmar pasa a `AUTHORIZED` y si automático a `CAPTURED/SUCCEEDED`.
- QR: `REQUIRES_ACTION` + `qr_code` string; `POST /qr_payments/{id}/simulate` mueve a `AUTHORIZED` y sigue flujo.

### Captura manual
`POST /api/v1/payment_requests/{id}/capture`
- Solo `status=AUTHORIZED` y `capture_method=MANUAL`.
- Idempotente por `X-Request-ID`.

### Refunds
`POST /api/v1/payment_requests/{id}/refunds`
- Solo `SUCCEEDED`.
- Permite parciales múltiples; rastrea `refunded_amount`.
- Si total, el pago pasa a `REFUNDED`.

### Void
`POST /api/v1/payment_requests/{id}/void`
- Solo `AUTHORIZED` no capturado.
- Cambia estado a `VOIDED`.

## 6. Webhooks
- Todos los cambios de estado disparan evento a `callback_url` del merchant.
- Header `X-Webhook-Signature: sha256=<HMAC(webhook_secret, raw_body)>`.
- Reintentos: al menos 3 con backoff simple (p.ej. 1s, 3s, 9s) hasta `200 <= code < 300`.
- Incluye `event`, `business_id`, `created`, `data` (entidad completa relevante) y `request_id` si aplica.

Eventos mínimos:
- `payment_method.auth_completed`
- `payment.authorized`
- `payment.captured`
- `payment.succeeded`
- `payment.failed`
- `refund.succeeded`
- `void.succeeded`

## 7. Modelo de datos (conceptual)
Mantén prefijos (`pm-`, `pr-`, `tok-`, `rf-`).
- `merchants(id, business_name, api_key, api_secret, webhook_secret, status, timestamps)`
- `payment_methods(id, merchant_id, type, status, reusability, token_id, card_fingerprint, masked_card_number, card_network, card_type, expiry_month, expiry_year, cardholder_name, cardholder_email, metadata, timestamps)`
- `three_d_secure_challenges(id, payment_method_id, payment_request_id?, status, challenge_url, eci_code, version, timestamps)`
- `payment_requests(id, merchant_id, payment_method_id?, reference_id, amount, currency, status, capture_method, description, failure_code, callback_url, success_return_url, failure_return_url, captured_amount, refunded_amount, metadata, timestamps)`
- `refunds(id, payment_request_id, merchant_id, amount, reference_id, reason, status, timestamps)`
- `webhook_events(id, merchant_id, event_type, payload, status, attempts, last_attempt_at, response_code, timestamps)`

## 8. Errores estándar
Respuesta:
```json
{
  "error_code": "INVALID_CARD_NUMBER",
  "message": "The card number failed Luhn validation",
  "errors": [{"field": "card.card_number", "message": "Invalid card number"}]
}
```
Códigos relevantes: `AUTHENTICATION_FAILED (401)`, `MERCHANT_SUSPENDED (403)`, `INVALID_CARD_NUMBER (422)`, `CARD_EXPIRED (422)`, `INVALID_AMOUNT (422)`, `PAYMENT_METHOD_NOT_FOUND (404)`, `PAYMENT_NOT_FOUND (404)`, `INVALID_PAYMENT_STATE (409)`, `REFUND_EXCEEDS_AMOUNT (422)`, `DUPLICATE_REFERENCE_ID (409)`, `THREE_DS_AUTHENTICATION_FAILED (422)`.

## 9. Semillas y testing manual rápido
- Crea 5 merchants con combos `(pk_test_xxx, sk_test_xxx, webhook_secret_xxx, status=active)` y, al menos uno, `status=suspended` para probar 403.
- Incluye scripts/cURL en README para: tokenizar sin 3DS, tokenizar con 3DS fallida, pago con PM, pago directo con 3DS, eWallet, QR + simulate, refund parcial, void inválido.
- Si usas Docker: `docker-compose up --build` levanta API en `http://localhost:3000`, challenge en el mismo host (`/3ds/challenge/:id`).

## 10. Criterios de evaluación
| Área | Peso | Observables |
|------|------|-------------|
| API Design | 25% | Rutas coherentes, status codes, estructura de respuesta, idempotencia |
| Payment Flow Correctness | 25% | Transiciones válidas, 3DS, captura/void/refund |
| Security | 20% | Auth, HMAC webhooks, no exponer PAN completo, validar entrada |
| Code Quality | 15% | Arquitectura limpia, servicios, tests útiles, logs claros |
| Data Design | 15% | Índices/constraints básicos, tracking de montos y estados |

## 11. Extensiones opcionales (bonus)
- Rate limiting por merchant.
- Dashboard React mínimo para ver pagos y reintentar webhooks.
- Auditoría/bitácora de eventos.
- API versioning (`/api/v1`).
