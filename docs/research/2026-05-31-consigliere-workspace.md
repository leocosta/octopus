# Research: consigliere-workspace

**Date:** 2026-05-31
**Trigger:** Manager pain point — acompanhar reuniões e digerir documentos diversos (Slack, transcrições de Meet, Jira, Confluence) é feito hoje de forma fragmentada. Detalhes que importam (impedimentos, decisões, mapa de sistemas, risco político) não vivem no Jira. Sessão derivada de uma `interview` concluída no mesmo dia, que já convergiu o intent — esta pesquisa só fatia em itens de roadmap.

## Context

Sub-iniciativa do **Cluster 16 — Manager multiplier** (já completo: RM-089…096, RM-098). Enquanto o Cluster 16 cobre o manager como multiplicador do **time** (pedagogia, knowledge loop, cross-repo), o **consigliere** cobre o manager como multiplicador de **si mesmo**: um acervo privado de conhecimento gerencial que digere insumos e mantém memória viva de status, impedimentos e sistemas.

A metáfora é literal: um *Chief of Staff* corporativo é o "force multiplier" do executivo — filtra informação, acompanha prioridades, detecta risco e desalinhamento, conecta silos e guarda a memória institucional. Aqui o executivo servido é o próprio manager — um chief-of-staff *pessoal*. O role recebeu o nome **`consigliere`** (uma palavra, convenção de roles do Octopus; conota conselheiro de confiança que conhece a política e sussurra o risco — exatamente o campo "riscos políticos").

Reusa guardrails já existentes: **`audit-grounding`** (RM-088, shipado v1.69.0) para o grounding estrito, e o padrão **continuous-learning / review-proposals** para o loop de heurísticas.

## Analysis

### Modelo de dados (o núcleo)

- **Contexto** = nó **perene** numa árvore de profundidade arbitrária (produto → domínio → sub-domínio). Cada nó tem **estado materializado próprio** (não rollup computado). Ex: `tatame` (SaaS de gestão de academias) → `jiu-jitsu` (domínio de negócio estável).
- **Projeto** = entidade **temporal** (início/meio/fim), **transversal** — relação muitos-pra-muitos com contextos, podendo cruzar workspaces. Ex: `pos-activation` atravessa `tms` e `pos`.
- **Trio uniforme por nó** (contexto ou projeto): `state.md` (materializado) + `journal.md` (append-only datado) + `playbook.md` (heurísticas, opcional).
- **Escrita transversal = fan-out de ponteiro:** o detalhe (6 campos) mora no projeto; o digest propaga uma linha-resumo pro `state.md` de cada contexto cruzado, mantendo cada contexto autossuficiente para consulta sem recomputar.

### Layout do `manager-workspace` (repo privado, nunca commitado em repo de time)

```
manager-workspace/
├── README.md                       # manual de operação
├── sources/YYYY/MM/<data>-<slug>.md   # insumos brutos, imutáveis (frontmatter: origin, fetched_at) — base do grounding
├── contexts/<arvore>/              # cada nó: state.md · journal.md · playbook.md
├── projects/<proj>/                # state.md · journal.md · meta.yml (contexts: [...])
└── people/<pessoa>.md              # heurísticas por pessoa
```

### Contrato do digest — 6 campos

status por frente · impedimentos+dono · decisões · mapa de sistemas/áreas · ações+owners · **riscos políticos** (sinais org/humanos que não vão pro Jira: conflito de prioridade entre áreas, sponsor/decisão pendente, expectativa desalinhada, bus-factor, retrabalho por decisão revertida).

### Fluxo de captura

`/digest-source <texto | pdf | JIRA-123 | url-confluence> "descrição em linguagem natural"` →
snapshot imutável em `sources/` → **infere** contexto/projeto da frase NL → **confirma** (cria nó on-the-fly se não existir) → extrai os 6 campos grounded com citação de origem → **preview** do que vai gravar → **grava** (fan-out). A frase natural É o roteamento; ambiguidade vira pergunta, não chute.

### Multi-modal — viabilidade honesta

| Fonte | Ingestão | Hoje |
|---|---|---|
| Texto colado | direto | ✅ |
| PDF (caminho local) | CC lê nativamente | ✅ |
| Jira | MCP existente | ✅ |
| Confluence (link) | precisa de MCP/token Atlassian | ⚠️ inexistente → fallback export-PDF |

### Loop de aprendizado (o que separa "anotador" de "consigliere")

Bidirecional: o manager **semeia** heurísticas que já tem (escreve direto no `playbook.md`) **e** o agente **captura** novas dos digests (propõe → o manager confirma via `playbook-review`). Aplicadas **push** (cutuca ao ler insumo novo: "owner tende a atrasar → sugiro FUP") e **pull** (na consulta).

### Constraints duras

- **Grounding estrito:** nunca afirmar o que não está explícito no insumo ou numa heurística aprovada; na dúvida, perguntar; todo claim rastreia a `sources/`. (Reusa `audit-grounding`.)
- **Privacidade:** workspace privado, single-user; transcrições e riscos políticos jamais num repo de time.

### Nomenclatura fechada

- **Role:** `consigliere`
- **Skills:** `digest-source` · `context-status` · `playbook-review`
- **Bundle novo:** `consigliere`
- `context-init` foi **descartado** — criação de nó é **on-the-fly** dentro do `digest-source` (sob confirmação).

### Decisões de arquitetura

1. **Onde os artefatos nascem** → **resolvido em [ADR-007](../adr/007-consigliere-artifact-location.md):** role+skills shipam **genéricos no Octopus**, operando sobre um `manager-workspace` apontado por config; os *dados* ficam sempre no workspace privado.
2. **Bundle `consigliere` separado vs fundido com `tech-lead`** → **resolvido em [ADR-008](../adr/008-consigliere-bundle-separation.md):** bundle **separado** (audiência/dado/contexto de ativação diferentes).
3. **Formato/escopo do `playbook`** (por contexto vs central) e como o role consulta sem inchar contexto → **pendente**, a fechar no spec do RM-103.

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-099 | `consigliere` workspace scaffold + bundle | 🔴 High | medium |
| RM-100 | `digest-source` skill — captura multi-modal grounded com fan-out | 🔴 High | high |
| RM-101 | `consigliere` role — lente/voz que aprende heurísticas | 🔴 High | medium |
| RM-102 | `context-status` skill — consulta NL sobre estado materializado | 🟡 Medium | low |
| RM-103 | `playbook-review` skill + loop de aprendizado de heurísticas | 🟡 Medium | medium |
| RM-104 | Integração MCP Atlassian — Confluence + Jira enriquecido | 🟡 Medium | low |

## Discarded Items

| Title | Reason |
|---|---|
| `context-init` skill (registro prévio de nó) | Nome colide com `/init` e `doc-subcontext`; criação de nó vira **on-the-fly** no `digest-source` sob confirmação. Renasce como `register-context` só se on-the-fly não bastar na prática. |
