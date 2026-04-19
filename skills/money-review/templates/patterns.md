# Money-Review Patterns (default)

> Embedded default. Override at `docs/money-review/patterns.md`.
> The override appends to these defaults — it does not replace them.

## Filename tokens

billing, payment, charge, cobran, split, invoice, subscription, asaas,
stripe, pix, webhook, refund, reembolso, tax, taxa, fee

## Content regex (case-insensitive)

- `\b(PERCENT|PERCENTAGE|RATE|FEE)[_A-Z]*\s*=`
- `\bdecimal\b` near `cents|centavos|amount|valor` (C#)
- `\bBigInt\b|\bNumber\(` near `cents|centavos|amount|valor` (TS/JS)
- `asaas|stripe|mercadopago`
- `webhook` with `signature|hmac|signing`

## Cents patterns (for T3 test inspection)

Any of: `\b\d+\.(01|99|55|33|45|77)\b`, `\b\d+_(01|99|55|33)\b`.
