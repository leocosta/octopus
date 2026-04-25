# Security-Scan Patterns (default)

> Embedded default. Override at `docs/security-scan/patterns.md`.
> Overrides append; they do not replace the defaults.

## Path tokens

auth, jwt, oauth, secret, token, password, credential, permission, role,
middleware, .env, login, signup, session, cookie

## Content regex

- `\bsk-\w+`
- `ghp_[A-Za-z0-9]+`
- `Bearer\s+[A-Za-z0-9._-]+`
- `api_key\s*=|apikey\s*=|API_KEY\s*=`
- `password\s*=|PASSWORD\s*=|passwd\s*=`
- `secret\s*=|SECRET\s*=|private_key`
- `dangerouslySkipPermissions|--no-verify`
