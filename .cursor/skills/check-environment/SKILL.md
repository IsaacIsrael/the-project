---
name: check-environment
description: Run the project CLI to check or fix the dev environment (Node, npm, nvm). Use when the user asks to check environment, verify setup, check versions, or fix local setup.
---

# Check environment

Use this skill when the user wants to **check the development environment** or **verify/fix setup** (Node, npm, nvm). The project provides a CLI: **doctor** (version checks) and **install** (nvm → Node from .nvmrc → npm install). Run from the repo root.

---

## Workflow

### 1. Run doctor (no banner)

From the repo root:

```bash
npm run cli -- --no-banner doctor
```

Or:

```bash
bash scripts/cli.sh --no-banner doctor
```

This runs the version check and prints: nvm installed/configured/auto-load, Node version, npm version, and a pass/fail summary.

### 2. Summarize results (with visual emoji)

Present the outcome **visually** in your reply to the user:

- **If passed:** show this line, then a short confirmation:
  ```
  ✅  ✅  ✅   PASSED   ✅  ✅  ✅
  ```
  Then: "Environment is OK — Node, npm, and nvm match project requirements."

- **If failed:** show this line, then list what failed and suggest install:
  ```
  ❌  ❌  ❌   FAILED   ❌  ❌  ❌
  ```
  Then list what failed (e.g. nvm not installed, Node version mismatch, nvm not in profile) and suggest running **install** to fix:

```bash
npm run cli -- --no-banner install
```

### 3. Optional: run install

If the user asks to **fix** or **set up** the environment, or after doctor fails and they confirm, run:

```bash
npm run cli -- --no-banner install
```

This will: ensure nvm is installed, add nvm to shell profile, add zsh .nvmrc auto-load (if zsh), ensure Node from .nvmrc, then `npm install`. Summarize what was done.

---

## When to use

- User says: "check the environment", "verify setup", "check versions", "is my env correct?", "fix my local setup".
- Before suggesting run/build commands if you suspect a version or tooling issue.
- After clone or when onboarding: "run the environment check" or "set up the project".

Use **doctor** for a quick check; use **install** when something is missing or the user wants to set up from scratch.
