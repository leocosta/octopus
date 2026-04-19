# Payment Provider Patterns (default)

> Embedded default. Override at `docs/money-review/providers.md`.

## Asaas

- Idempotency via `externalReference` field in payment/charge requests.
- Webhook events signed with `asaas-access-token` header (custom token).
- Sandbox base URL: `https://sandbox.asaas.com/api/v3`.

## Stripe (fallback guidance)

- Idempotency via `Idempotency-Key` header.
- Webhook events signed with `Stripe-Signature` (HMAC-SHA256).

## Mercado Pago

- Idempotency via `X-Idempotency-Key` header.
- Webhook signed with `x-signature` + `x-request-id`.
