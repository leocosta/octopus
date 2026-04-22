---
name: security-scan
description: Security audit checklist for AI agent configurations, environment variables, and project dependencies
triggers:
  paths: []
  keywords: ["auth", "jwt", "oauth", "secret", "token", "sql", "password", "credential"]
  tools: []
pre_pass:
  file_patterns: "auth|jwt|oauth|secret|token|password|credential|permission|role|middleware|\\.env"
  line_patterns: "password|secret|Bearer|Authorization|SQL|querySelector"
---

# Security Scan

## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Then follow the Cache protocol in `skills/_shared/audit-cache.md` before proceeding to audit areas.

## When to Use

- After initial project setup or Octopus configuration
- Before deploying to production
- When adding new MCP servers or integrations
- Periodic security review (monthly recommended)
- After a team member change (rotate credentials)

## Audit Areas

### 1. Environment Variables & Secrets

**Check for exposed secrets:**
- Scan all files for hardcoded API keys, tokens, passwords
- Patterns to look for: `sk-`, `ghp_`, `Bearer`, `api_key=`, `password=`
- Verify `.env.octopus` and `.env*.local` are in `.gitignore`
- Check git history for accidentally committed secrets

```bash
# Search for potential secrets in codebase
grep -rn "sk-\|ghp_\|api_key\|secret_key\|password\s*=" --include="*.ts" --include="*.cs" --include="*.py" .
```

**Verify secret management:**
- [ ] All secrets loaded from environment variables
- [ ] `.env.octopus` files are in `.gitignore`
- [ ] No secrets in committed configuration files
- [ ] Required secrets validated at application startup

### 2. Agent Configuration (CLAUDE.md, AGENTS.md)

**Check for:**
- [ ] No secrets or tokens in agent instructions
- [ ] No overly permissive tool permissions
- [ ] No instructions that bypass security checks
- [ ] No prompt injection vulnerabilities in templates

### 3. MCP Server Security

**Review each MCP server in settings.json:**
- [ ] Server source is trusted and maintained
- [ ] Environment variables for tokens use `${VAR}` syntax (not hardcoded)
- [ ] HTTP-based MCP servers use HTTPS
- [ ] Server permissions are scoped appropriately (read-only when possible)

### 4. Claude Code Settings (settings.json)

**Check permissions:**
- [ ] `permissions` are not overly broad
- [ ] No `dangerouslySkipPermissions` or equivalent
- [ ] Hook scripts don't execute arbitrary user input
- [ ] Auto-approved tools are reviewed and justified

### 5. Hook Security

**Review hook scripts for:**
- [ ] No command injection vulnerabilities (unquoted variables in shell)
- [ ] No use of `eval` with external input
- [ ] Scripts validate input before processing
- [ ] Timeouts are set to prevent runaway processes

### 6. Dependency Vulnerabilities

**Run dependency audits:**

```bash
# Node.js
npm audit

# .NET
dotnet list package --vulnerable

# Python
pip-audit  # or: safety check
```

- [ ] No critical/high vulnerabilities in dependencies
- [ ] Audit runs in CI pipeline
- [ ] Lock files are committed (package-lock.json, packages.lock.json, uv.lock)

### 7. Git & Repository Security

- [ ] Branch protection rules are enabled on main
- [ ] No force-push to main/master
- [ ] Signed commits enabled (recommended)
- [ ] `.gitignore` includes all generated and sensitive files

## Severity Classification

| Severity | Description | Action |
|----------|-------------|--------|
| **Critical** | Exposed secrets, no auth on endpoints | Fix immediately |
| **High** | Missing input validation, overly permissive configs | Fix before deploy |
| **Medium** | Missing dependency audit, stale credentials | Fix within sprint |
| **Low** | Missing branch protection, unsigned commits | Track in backlog |

## Output Format

```
Security Scan Report
====================
Date: YYYY-MM-DD
Score: B (72/100)

CRITICAL (0)
  (none)

HIGH (2)
  [H1] .env.octopus not in .gitignore — secrets may be committed
  [H2] MCP server 'notion' uses hardcoded token in settings.json

MEDIUM (1)
  [M1] No npm audit in CI pipeline

LOW (1)
  [L1] Branch protection not configured on main

Recommendations:
  1. Add .env.octopus to .gitignore immediately
  2. Move Notion token to environment variable
  3. Add `npm audit` step to CI workflow
  4. Enable branch protection rules
```
