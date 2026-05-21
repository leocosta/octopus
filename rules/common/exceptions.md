# Exceptions

> **Override:** create `exceptions.local.md` in this directory to replace these conventions entirely. The local file takes full precedence.

A custom exception is **a contract you owe the caller and the operator**, not a stylistic upgrade over the stdlib type. Creating one without the gate below pollutes the domain with throw-once classes that nobody catches and nobody reads.

## Default — do NOT create a custom exception

Reach for one of these first, in order:

1. **Return a typed result** for *expected* failures inside a single bounded context — see the Result pattern in `patterns.md` (and stack-specific guidance like `csharp/error-handling.md`).
2. **Throw the closest stdlib / framework exception** with a precise message — `ValueError`, `KeyError`, `InvalidOperationException`, `ArgumentException`, `TypeError`. These are universally understood and require no new type.
3. **Fail fast with `assert` / `panic` / `Debug.Assert`** for invariants that must never trigger in a correct caller — these are bugs, not failures.

If one of the three above works, you are done. Do not create a class.

## Gate — when a custom exception IS justified

Create a custom exception **only if at least one of the following is true**, and the justification is written down (PR description, ADR, or docstring on the type):

### G1. Domain contract — callers disambiguate by type

The failure represents a named state in the domain that *another module already has code to handle*, and that handler distinguishes this case from other failures by catching the specific type.

- Minimum: **2+ call sites catch this specific type**, OR the exception is part of a published interface (REST mapping, library API, gRPC, plugin contract).
- One throw site + zero catch sites = **not a contract**. Throw stdlib.

### G2. Operational diagnostic — structured fields the operator queries

The exception carries **fields that operational tooling reads** — log search, retry policy, circuit-breaker key, alert filter, runbook trigger. The type name and fields make the failure searchable and triageable without parsing free-text messages.

- Minimum: at least one structured field beyond `message` (e.g. `gateway_name`, `attempt`, `customer_id`, `retry_after_ms`) AND a real consumer (log query, dashboard, retry middleware) that reads it.
- "Could be useful later" = **not a diagnostic**. Wait until the consumer exists.

### G3. Crossing a trust boundary with a wrap

You are catching an infrastructure exception (DB driver, HTTP client, file system) and rethrowing as a domain exception **to attach domain context** the original lacks. The wrap is justified only if it adds fields from §G2 *and* the original is preserved as the inner/cause exception.

- Wrapping a `SqlException` as `OrderRepositoryException("save failed", cause=ex)` with no extra fields = **noise, not a wrap**.

## Forbidden — these are domain pollution

| Smell | Why it is forbidden |
|---|---|
| `FooNotFoundException`, `FooAlreadyExistsException` mirroring stdlib semantics with no extra fields | duplicates `KeyError`/`KeyNotFoundException` without adding contract or diagnostic |
| One throw site, zero catch sites in the entire repo | not a contract; nobody is reading the type |
| Wrapper that hides the cause (`raise MyException()` without `from e`, `throw new X()` without `innerException`) | destroys the stack trace; replaces real diagnostics with branding |
| Speculative subtype hierarchies (`abstract DomainException` → 8 empty subclasses "for future use") | YAGNI; create the subtype the day a caller catches it, not before |
| Exception for control flow inside one function (`raise ContinueLoop`, `throw RetrySignal`) | use a sentinel return, a state machine, or a local flag |
| Renaming a stdlib exception ("our codebase calls it `NotAuthorizedError` not `PermissionError`") | aesthetic, not semantic; pick the stdlib name and move on |
| One exception per validation rule (`EmailFormatException`, `EmailTooLongException`, `EmailMissingDomainException`) | use a validation library that returns a list of errors |

## When you delete code

If you remove the last catch site of a custom exception, the class itself becomes dead. **Delete the class in the same change.** Custom exceptions with no remaining handlers are worse than no custom exception — they advertise a contract that no longer holds.

## Message and cause — written for 2 AM

Assume the exception will be read at 2 AM during a production incident by someone unfamiliar with the code. The message states what was expected, what was received, and includes the identifiers (`paymentId`, `tenantId`, etc.) the operator needs to find the affected record. The cause is always preserved so the stack trace points at the real root.

Bad:

```text
Invalid input
```

Good:

```text
InvalidPaymentAmount: amount must be > 0 BRL.
Received: -150.00 BRL. paymentId=pay_8f3k2m, tenantId=t_42.
```

## Per-language notes

Each block shows the **same domain failure** badly (generic exception, no context, cause discarded) and well (gate-passing custom type with fields and cause chaining). The "good" form only exists because there is a real catch site and a real operational consumer — without those, throw the stdlib type instead.

### C#

Bad:

```csharp
if (amount <= 0)
    throw new ArgumentException("Invalid amount");

try { await _stock.Reserve(orderId); }
catch (Exception ex) { throw new Exception("payment failed"); }
```

Good:

```csharp
public sealed class InvalidPaymentAmountException : Exception
{
    public decimal Amount { get; }
    public string PaymentId { get; }

    public InvalidPaymentAmountException(decimal amount, string paymentId)
        : base($"Amount must be > 0. Received: {amount} BRL. paymentId={paymentId}")
    {
        Amount = amount;
        PaymentId = paymentId;
    }
}

if (amount <= 0)
    throw new InvalidPaymentAmountException(amount, paymentId);

try { await _stock.Reserve(orderId); }
catch (StockUnavailableException ex)
{
    throw new PaymentProcessingException(paymentId, orderId, ex);
}
```

Derive from `Exception`, not `ApplicationException` (reserved/deprecated). Always preserve `innerException`. Result-pattern guidance for expected failures lives in `csharp/error-handling.md`.

### Python

Bad:

```python
if amount <= 0:
    raise ValueError("invalid amount")

try:
    reserve_stock(order_id)
except Exception:
    raise Exception("payment failed")
```

Good:

```python
class InvalidPaymentAmount(ValueError):
    def __init__(self, amount: Decimal, payment_id: str) -> None:
        super().__init__(
            f"Amount must be > 0. Received: {amount} BRL. payment_id={payment_id}"
        )
        self.amount = amount
        self.payment_id = payment_id

if amount <= 0:
    raise InvalidPaymentAmount(amount, payment_id)

try:
    reserve_stock(order_id)
except StockUnavailable as ex:
    raise PaymentProcessingError(payment_id, order_id) from ex
```

Derive from the closest stdlib base (`ValueError`, `LookupError`, `RuntimeError`) so callers can catch broadly when they want to. Use `raise X from e` to preserve the cause.

### TypeScript

Bad:

```ts
if (amount <= 0) throw new Error("invalid amount");

try { await reserveStock(orderId); }
catch (e) { throw new Error("payment failed"); }
```

Good:

```ts
class InvalidPaymentAmountError extends Error {
  constructor(
    public readonly amount: number,
    public readonly paymentId: string,
  ) {
    super(`Amount must be > 0. Received: ${amount} BRL. paymentId=${paymentId}`);
    this.name = "InvalidPaymentAmountError";
  }
}

if (amount <= 0) throw new InvalidPaymentAmountError(amount, paymentId);

try {
  await reserveStock(orderId);
} catch (e) {
  throw new PaymentProcessingError(paymentId, orderId, { cause: e });
}

// In-process flow that does not cross a trust boundary — prefer a discriminated result:
type PayResult =
  | { ok: true; receiptId: string }
  | { ok: false; error: { kind: "invalid-amount"; amount: number; paymentId: string } };
```

Extend `Error`, set `name` to the class name, capture the cause via `new Error(msg, { cause: e })`.

### Counter-example — looks good, still forbidden

Fields and a nice name do not earn the type. With zero catch sites and no operational consumer, this is still pollution:

```csharp
public sealed class EmailFormatException : Exception
{
    public string Email { get; }
    public EmailFormatException(string email) : base($"Bad email: {email}") { Email = email; }
}

if (!IsEmail(input)) throw new EmailFormatException(input);  // FORBIDDEN until §G1 or §G2 is met
```

Use validation that returns a list of errors, or throw `ArgumentException` with a precise message.

## Self-check before adding `class XException`

Answer all four. If any is "no" or "not yet", do not create the class.

1. Is there an existing call site that will catch this **type** (not a generic `except Exception`/`catch (Exception)`)?
2. Does the type carry at least one structured field that an operator or another module will read?
3. Does the closest stdlib exception genuinely fail to express this case — not just feel less branded?
4. Will the class be deleted automatically when the last catch site goes away (or are you committing to delete it manually)?
