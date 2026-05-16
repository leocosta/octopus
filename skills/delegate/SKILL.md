---
name: delegate
description: >
  Delegate one task or a multi-step role pipeline to Octopus roles and return
  results inline with attribution. Triggers on @<role>: pattern in user
  messages, multi-role chained messages (PT-BR or EN), or via
  /octopus:delegate.
---

# Delegate — Inline Task Delegation to Roles

## When This Skill Applies

This skill activates when the user's message matches any of:

- `@<role>: <task>` — single dispatch (anywhere in the message)
- `/octopus:delegate @<role> <task>` — slash form
- **Pipeline form** — 2+ `@<role>` mentions combined with sequencing
  language in PT-BR or EN (e.g. "após", "ao final", "then", "after",
  "depois", "em seguida", "finally")

These do NOT trigger this skill:

- `@src/components/Button.tsx` — file mention (no colon, no sequencing)
- `@backend-developer` — bare mention, no colon, no chaining
- `@role:` with empty task body — ask for the task instead

---

## Mode Detection

Count `@<role>` mentions and scan for sequencing keywords:

- **1 mention, no sequencing keywords** → **Section A** (single dispatch, existing behavior)
- **2+ mentions OR explicit sequencing keywords** → **Section B** (pipeline dispatch)

**Sequencing keywords** (case-insensitive):
- PT: `após`, `depois`, `em seguida`, `ao final`, `por fim`, `quando terminar`, `assim que`, `após validação`, `ao terminar`
- EN: `then`, `after`, `afterward`, `finally`, `at the end`, `once done`, `when done`, `next`

**Parallel joiners** (within one step):
- PT: ` e `, `juntamente com`, `simultaneamente`, `em paralelo`
- EN: ` and `, `+`, `together with`, `in parallel`

---

## Section A — Single Dispatch

### A1 — Parse

Extract from the message:

- `role` — the identifier between `@` and `:` (e.g. `backend-developer`)
- `task` — everything after `:`, trimmed

### A2 — Validate role

Resolve `role` through the alias table (Section C). Check
`.claude/agents/<resolved-role>.md` (or `.opencode/agents/...`).

**If role not found:** list available roles by scanning the agents
directory, then respond:

```
Role "@<role>" not found. Available roles:
- architect
- backend-developer
- frontend-developer
- product-manager
- tech-writer
(adjust to whatever is installed)

Re-send your message with one of the roles above.
```

**If task is empty:** respond with:

```
What should @<role> do? Re-send with the task after the colon.
Example: @<role>: <your task here>
```

### A3 — Dispatch

**Native agents** (when the `Agent` tool is available):

```
Agent(
  subagent_type = "<resolved-role>",
  description   = "Delegated task: <first 60 chars of task>",
  prompt        = "<full task>"
)
```

**Inline harnesses** (no `Agent` tool): switch to that role's persona
for this turn only and respond as the role. Do not explain the switch.

### A4 — Format output

```
» <role> respondeu:

<agent response here>
```

---

## Section B — Pipeline Dispatch

### B1 — Parse the pipeline

Produce an ordered list of steps. Each step has:
- `index` (1-based)
- `parallel` (boolean — true when roles are joined by a parallel joiner)
- `members[]` — each `{ role, task }`

**Algorithm:**

1. Split the message into **clauses** on sequencing keywords. Each clause is one step.
2. Within each clause, find every `@<role>` token. If 2+ are joined by a parallel joiner, the step is `parallel: true`.
3. For each role in a clause, derive the `task`:
   - If followed by `:` with explicit text → use that text.
   - Otherwise → use the surrounding clause minus directive verbs (`delegue`, `apresente`, `peça`, `delegate`, `ask`, `have`, `solicite`) and the role token itself.
4. Keep phrases like "a spec produzida", "the result above", "o documento anterior" verbatim in the task — context threading (B4) injects prior outputs so the role can resolve them.

If parsing produces zero steps, fall back to Section A.

### B2 — Pre-flight validation

Resolve ALL roles across all steps through the alias table (Section C).
Verify each exists in `.claude/agents/<resolved-role>.md`.

**If any role is missing:** abort before executing anything. Respond:

```
Pipeline não iniciado — roles ausentes:

- @<missing>  (existe roles/<missing>.md; copie para .claude/agents/ para instalar)
- @<other>    (sem equivalente local)

Roles disponíveis: <comma-separated list>

Reformule ou instale os roles antes de prosseguir.
```

### B3 — Plan preview + initial gate

Always show the parsed plan before executing anything (even in auto mode):

```
» Pipeline detectado — <N> etapas, <M> dispatches no total

  1. @<role>                    — <task, ~80 chars>
  2. @<role>                    — <task>
  3. @<r1> + @<r2> (paralelo)  — <task>
  4. @<role>                    — <task>

Validação de roles: ok (<M>/<M> encontradas)
Iniciar pipeline? [y/s = começar · auto = rodar tudo sem parar · n = cancelar · edit = reescreverei a mensagem]
```

Interpret the answer:
- `y`, `s`, `sim`, `yes`, blank → proceed step-by-step
- `auto`, `a`, `tudo`, `all` → proceed and set `autoMode = true`
- `n`, `no`, `cancel`, `parar`, `abort` → cancel without dispatching anything
- `edit` → respond "Ok, aguardando nova mensagem." and stop
- Anything else → re-ask once, then default to `n`

If the original message contained `--auto` or phrases like "rode tudo de uma vez" / "run all without stopping", start with `autoMode = true` (plan preview still shown, but proceed in the same turn).

### B4 — Execute steps

Maintain `pipelineContext` (string, initially empty) and `results[]`.

For each step in order:

**1. Compose prompt for each member:**

```
<member.task>

---
Contexto das etapas anteriores deste pipeline:

<pipelineContext>
```

If `pipelineContext` is empty, use `(esta é a primeira etapa)`.
Truncate each individual prior output to ~4000 chars in the context block,
appending `…[truncado — output completo no transcript]` when cut.

**2. Dispatch:**

- `parallel == true` AND `Agent` tool available → issue all member `Agent()` calls **in one assistant turn** (concurrent tool block). Wait for all results.
- `parallel == true` AND no `Agent` tool → execute sequentially via inline persona switch; note `(paralelo degradado para sequencial — harness sem Agent tool)` in the step header.
- `parallel == false` → single `Agent()` call or inline persona switch.

**3. Collect outputs** into `results[step.index]` keyed by member role.

**4. Append to pipelineContext:**

```
[Etapa <index> — <role>]
<output, truncated to ~4000 chars>

```

For parallel steps, append one block per member in declared order.

**5. Confirmation gate** (skip if `autoMode` or this is the last step):

```
» Etapa <i>/<N> concluída — <role(s)> respondeu (<chars> chars)

Próxima: Etapa <i+1>/<N> — <role(s)> — <task summary>

Continuar? [y/s · auto = rodar restantes sem parar · n = abortar · skip = pular próxima etapa]
```

Gate answers:
- `y`, `s`, `sim`, `yes`, blank → continue to next step
- `auto` → set `autoMode = true`, continue without further gates
- `n`, `abort`, `parar` → stop, jump to B5 with status `abortado`
- `skip` → record empty result for the NEXT step (mark as `pulada`), advance without dispatching, then gate again
- Anything else → re-ask once, default to `n`

### B5 — Final consolidated output

```
» Pipeline <status> — <completed>/<total> etapas

═══ Etapa 1 — <role> respondeu ═══
<response>

═══ Etapa 2 — <role> respondeu ═══
<response>

═══ Etapa 3 (paralelo) ═══

— <role-a> respondeu:
<response>

— <role-b> respondeu:
<response>

═══ Etapa 4 — <role> respondeu ═══
<response>
```

`status` is one of: `concluído`, `abortado`, `parcial`.
Skipped steps show `(pulada)` instead of a response block.

---

## Section C — Role Alias Table

Resolve before validation in both single and pipeline mode:

| Input | Resolves to |
|---|---|
| `writer`, `tech-writer` | `tech-writer` |
| `pm`, `product-manager` | `product-manager` |
| `staff-engineer`, `staff`, `architect` | `architect` |
| `frontend`, `fe`, `frontend-developer`, `frontend-specialist` | `frontend-developer` |
| `backend`, `be`, `backend-developer`, `backend-specialist` | `backend-developer` |
| `marketer` | `marketer` |
| `social-media`, `social` | `social-media` |
| `dream` | `dream` |

If a resolved role is missing from `.claude/agents/` but exists in `roles/<role>.md`,
include that path in the error message as an installation hint.

---

## Section D — Examples

### Single dispatch (unchanged behavior)

```
@backend-developer: add POST /invoices endpoint
```

→ dispatches to backend-developer, returns `» backend-developer respondeu: ...`

### Pipeline, step-by-step

```
@tech-writer: cria uma spec para gestão de planos de aula.
Após documentar, apresente para @product-manager revisar.
Após validação, delegue a implementação para @frontend-developer e @backend-developer.
Ao final, delegue ao @architect para code review.
```

Flow:
1. Plan preview + initial gate.
2. Dispatch tech-writer → gate.
3. Dispatch product-manager with tech-writer output in context → gate.
4. Parallel dispatch frontend-developer + backend-developer (both receive prior context) → gate.
5. Dispatch architect with all prior outputs in context → final consolidated output.

### Auto mode

Same prompt with `--auto` appended, or "rode tudo de uma vez" included,
runs all steps without intermediate gates (plan preview still shown once).
