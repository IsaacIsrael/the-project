---
name: start-task
description: >-
  Starts work on a GitHub task: syncs tasks from GitHub, lists open stories and
  their open tasks, optionally creates a Conventional Branch feature branch from
  the repo default branch, warns prominently if the user is not on the default
  branch, then opens or updates a feature PR linked to the chosen issue. Use
  when the user wants to start a task, begin work on an issue, spin up a branch
  for a task, or kick off a task with an initial PR.
---

# Start a task

Use this skill when the user wants to **start work on a task** (GitHub issue): refresh task state, pick a task from open stories, create a **`feature/<issue>-<slug>`** branch per [Conventional Branch](https://conventional-branch.github.io/) (see [.cursor/rules/conventional-branch.mdc](../../rules/conventional-branch.mdc)), and open a **starter feature PR** linked to that issue.

**Depends on:** `gh`, `jq` (same as [sync-github-tasks](../../scripts/sync-github-tasks.sh)); Git. See README → **Project agent dependencies**.

---

## 1. Sync tasks (mandatory)

Run from repo root:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

If sync fails, stop and report (auth, network). Do not list tasks from stale `state.json` without a successful sync unless the user explicitly accepts stale data.

---

## 2. List open stories

After sync, derive **open stories** from `.cursor/context/tasks/state.json`:

- **Stories** are issues whose `labels` include **`storie`** (project convention) and `state` is **`open`**.

Present a compact list: **#N — title** with link from `html_url` when helpful.

Optional **jq** (readable table):

```bash
jq -r '.issues[] | select(.state=="open" and (.labels | index("storie") != null)) | "#\(.number) — \(.title)"' .cursor/context/tasks/state.json
```

You may also summarize from `.cursor/context/tasks/TASKS.md` if it matches sync output.

---

## 3. List open tasks grouped by story

**Tasks** are issues with label **`tasks`** and `state` **`open`**.

For each **open story** (from step 2), list **open child tasks**:

- Use `hierarchy.byNumber["<storyNumber>"].children` for child issue numbers.
- For each child number, resolve the issue in `issues[]` where `labels` contains `tasks`, `state` is `open`, and `number` matches.

Show groups like:

**Story #1 — [Story 0] Definitions**

- #9 — [Task 0.2] IDE Versions… (open)
- …

Stories with no open children can be omitted or shown as “(no open tasks).”

If the user already named a task (e.g. “start #9”), skip the full list or show only that task after confirming it exists and is open.

---

## 4. Default branch check and create branch

### Resolve default branch

Prefer (after `git fetch origin` if needed):

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

If empty, try `git remote show origin` / `main` / `master` / `git config init.defaultBranch` and pick the branch that exists on `origin`.

Let **`CURRENT`** = `git branch --show-current` and **`DEFAULT`** = resolved default branch.

### If `CURRENT` equals `DEFAULT`

- Propose branch name per [.cursor/rules/conventional-branch.mdc](../../rules/conventional-branch.mdc): **`feature/<issue-number>-<short-slug>`** (e.g. `feature/9-ide-versions`).
- After user confirms the task **and** branch name, create and switch:

```bash
git checkout -b "feature/<issue>-<slug>"
```

### If `CURRENT` is not `DEFAULT` — required warning

Do **not** proceed to branch creation until the user explicitly opts in.

Show a **highly visible** warning (use a level-1 heading inside a blockquote, warning emoji, and short bold copy so it stands out in the UI):

```markdown
> # ⚠️ You are not on the default branch
>
> **Current branch:** `CURRENT` · **Default branch:** `DEFAULT`
>
> Starting a task usually means branching **from** `DEFAULT` so your PR is clean. Do you still want to start this task now?
```

Optional: suggest `git checkout DEFAULT && git pull` before creating `feature/...`.

If the user **declines**, stop.

If the user **confirms** (“yes”, “go ahead”, “branch from main”, etc.), prefer creating the new branch from **`origin/DEFAULT`** (after fetch/pull) unless they explicitly want to branch from **`CURRENT`**:

```bash
git fetch origin
git checkout "$DEFAULT"
git pull --ff-only origin "$DEFAULT"
git checkout -b "feature/<issue>-<slug>"
```

Document what you did in one sentence.

---

## 5. Push branch

Ensure the branch exists on the remote (needed for PR creation):

```bash
git push -u origin "$(git branch --show-current)"
```

If push fails (network/sandbox), give the exact command for the user to run locally.

---

## 6. Create or update a starter feature PR

Goal: a **feature** PR for this branch, linked to **one task issue**, even if the body is still mostly template (“empty” starter).

1. **Issue number:** the selected task’s GitHub issue number (`--issue N`).
2. **Title:** short description derived from the task title (script adds **✨ [Feature]** prefix).
3. **Body:** do **not** require a filled-in PR body for this workflow. Run **`create-or-update-pr.sh` without `--body-file`** so the script uses `.github/PULL_REQUEST_TEMPLATE/feature.md` (placeholders are OK for a draft starter).

Follow [.cursor/skills/create-or-update-pr/SKILL.md](../create-or-update-pr/SKILL.md) for **preview + confirmation** before running the script: show **title**, **base** (`DEFAULT`), **head** (current branch), and **linked task #N**. The user must confirm (e.g. “yes”, “go ahead”) after the preview.

Example (after push and user confirms):

```bash
bash .cursor/scripts/create-or-update-pr.sh --type feature --title "Short title from task" --base DEFAULT --issue N
```

Replace `DEFAULT` with the actual default branch name (usually `main`). Use a concise **English** title fragment, not the raw long GitHub title if it is unwieldy.

If a PR already exists for this branch, the same script **updates** it.

Share the PR URL from the script output.

---

## Checklist

- [ ] `sync-github-tasks.sh` ran successfully.
- [ ] Open stories listed; open tasks listed per story (or user chose a specific `#N`).
- [ ] Default branch resolved; if not on default, **large warning** shown and user confirmed.
- [ ] Branch name matches [conventional-branch.mdc](../../rules/conventional-branch.mdc).
- [ ] Branch pushed with upstream.
- [ ] PR preview shown; user confirmed; `create-or-update-pr.sh` run with `--issue N` and without `--body-file` for starter body.
- [ ] PR link shared.

---

## Reference

| Topic | Where |
|-------|--------|
| Task state, sync | [.cursor/rules/tasks-and-github.mdc](../../rules/tasks-and-github.mdc) |
| Branch names | [.cursor/rules/conventional-branch.mdc](../../rules/conventional-branch.mdc) |
| PR script & confirmation | [.cursor/skills/create-or-update-pr/SKILL.md](../create-or-update-pr/SKILL.md) |
| Conventional Branch spec | [conventional-branch.github.io](https://conventional-branch.github.io/) |
