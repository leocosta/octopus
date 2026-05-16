# UI Conventions

> **Override:** create `ui-conventions.local.md` in this directory to replace
> these conventions with your project's actual components, helpers, and schemas.
> The local file takes full precedence.

## Mask Component

This project uses a designated component for all masked inputs.

When creating or editing any input that requires a mask, always use that
component. Never use a plain `<input>` for fields like CPF, CNPJ, phone,
CEP, or date.

## Field Patterns

For each field type, apply the designated mask component and formatter. Do not
inline mask logic in the component — always delegate to the helper functions.

### CPF
- **Input**: use the mask component with the CPF mask pattern
- **Display**: use the project's CPF formatter helper
- **Validation**: use the project's CPF Zod schema

### CNPJ
- **Input**: use the mask component with the CNPJ mask pattern
- **Display**: use the project's CNPJ formatter helper
- **Validation**: use the project's CNPJ Zod schema

### Phone
- **Input**: use the mask component with the phone mask pattern
- **Display**: use the project's phone formatter helper (e.g. `(11) 99999-9999`)
- **Validation**: use the project's phone Zod schema

### CEP
- **Input**: use the mask component with the CEP mask pattern (`#####-###`)
- **Display**: raw value is acceptable; formatter optional
- **Validation**: 8 numeric digits after stripping mask

### Date
- **Input**: use the mask component with `DD/MM/YYYY` pattern for pt-BR
- **Display**: use the project's date formatter — never `new Date().toLocaleDateString()` inline
- **Validation**: use the project's date Zod schema with pt-BR parsing

### Currency / Monetary Values
- **Input**: use the project's currency input component (controlled, formats on change)
- **Display**: use the project's currency formatter helper (BRL, pt-BR locale)
- **Storage**: store as integer cents — never as float
- **Validation**: positive integer — `z.number().int().positive()`

## Anti-patterns

Never do any of the following:

- `<input type="text" />` for CPF, CNPJ, phone, CEP, or date — always use the mask component
- Inline mask logic inside a component (`regex replace`, manual `slice`) — use the designated helper
- `Intl.NumberFormat` inline for currency display — use the project's currency formatter
- `value.replace(/\D/g, '')` scattered across components — strip in the helper, not inline
- Different mask libraries in different parts of the app — one library per project
