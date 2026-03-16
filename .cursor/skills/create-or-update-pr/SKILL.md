---
name: create-or-update-pr
description: Create or update a GitHub pull request for the current branch. Use when the user wants to create a PR, update an existing PR, open a pull request, or push their branch and get a PR link. If a PR already exists for the branch, it is updated; otherwise a new one is created. Requires preview and user confirmation before running create-or-update-pr.sh.
---

# Create or update a pull request

Use this skill when the user wants to **create a PR** or **update an existing PR** (open or refresh a pull request from their branch). **Do not run `create-or-update-pr.sh` until the user has seen a preview and confirmed.** Uses `.cursor/scripts/create-or-update-pr.sh` (which creates a new PR or updates the existing one for the current branch). Scripts are agent-only under `.cursor/scripts/` ([agent-scripts](.cursor/rules/agent-scripts.mdc)); dependencies (e.g. `gh`) in README ([agent-dependencies](.cursor/rules/agent-dependencies.mdc)). Any preview or context file you keep (e.g. for later review) must go under `.cursor/context/` ([agent-context](.cursor/rules/agent-context.mdc)).

**First action (do not skip):** As soon as the user asks to create or update a PR, run `bash .cursor/scripts/sync-github-tasks.sh` so `.cursor/context/tasks/state.json` is current. Then continue with the workflow.

**Create or update:** The script updates an existing PR for the current branch (title + body + milestone) if one exists; otherwise it creates a new PR.

**Confirmation is required:** Phrases like "update this PR", "create the PR", "update the PR", or "let's update" mean the user wants to start or continue the workflow — they are **not** confirmation to run the script. You **must** show the preview (step 3) and then **wait** for an explicit confirmation (e.g. "yes", "go ahead", "do it", "confirm") before running `create-or-update-pr.sh`. Do not run the script until the user has seen the preview and replied with a clear yes.

---

## Workflow: Create or update a PR

### 0. Sync first (mandatory)

**Run this before any other step.** Do not check branch, draft title, or show preview until sync has been run. State is needed for Development link and Milestone when the PR links an issue.

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

If sync fails (e.g. `gh` auth or network), say so and continue only once state is updated (user can run sync manually). Then proceed to step 1.

### 1. Check state first

(Sync from step 0 must already have been run.)

- **Current branch:** Run `git branch --show-current` (or ask the user which branch the PR is from).
- **Base branch:** Usually `main` or `master`; confirm with the user or infer from `git remote show origin` / default branch.
- **Commits ahead:** Run `git rev-list --count BASE...HEAD` (e.g. `main...HEAD`) to see how many commits will be in the PR. Optionally `git log BASE..HEAD --oneline` to list them.
- **Issue (for Development/Milestone):** The script only links an issue when you pass `--issue N`; the agent cannot know the issue number otherwise. **Establish it explicitly:** if the user said "this PR is for #7" or the branch/commits clearly reference one issue (e.g. `feature/7-bootstrap` or commit "Closes #7"), use that number. If it's not obvious, **ask the user:** "Which issue is this PR for? (issue number, or 'none'.)" Do not guess or pass an issue number from context unless the user or the branch/commits clearly tie the PR to that issue. If there is no linked issue, do not pass `--issue`.
- If the working tree has uncommitted changes or the branch is not pushed, say so and ask whether to commit/push first or create the PR from the current state (and push after).

### 2. Draft title and body

- **Title:** Must use **emoji + prefix** then a short description. Exactly one of:
  - **✨ [Feature]** — new feature (e.g. `✨ [Feature] Add linting for X`)
  - **🐛 [Fix]** — bug fix (e.g. `🐛 [Fix] Resolve login redirect loop`)
  - **🚑 [Hotfix]** — urgent production fix (e.g. `🚑 [Hotfix] Restore env fallback`)
  Propose based on the branch name and recent commits if the user doesn't specify; if unclear, ask which type (Feature / Fix / Hotfix) and the short title.
- **Body:** Use the template that matches the PR type for **section structure only**: **`.github/PULL_REQUEST_TEMPLATE/feature.md`** (✨ [Feature]), **`fix.md`** (🐛 [Fix]), or **`hotfix.md`** (🚑 [Hotfix]). The body file must contain **only the sections**: ## 📝 Description, ## 📋 What changed, ## 🌟 Impact, ## ℹ️ Additional information, ## 🏞️ Demo (as in the template). **Do not** include the template's intro line ("Use the **title** field…") or any Issue / Development / Milestone block in the body file. Fill in each section as relevant; omit or leave placeholder when not applicable. Pass `--issue N` only when you have established the linked issue (from the user or from branch/commits); the script then adds "Closes #N" (or Fixes) to the body so GitHub fills the Development sidebar and sets the Milestone. If you don't know the issue, **ask the user** before drafting the body or running the script. If there is no linked issue, omit `--issue`.
- **Base:** Branch to merge into (e.g. `main`). **Head:** Branch to merge from (current branch unless user says otherwise).
- **Script:** `bash .cursor/scripts/create-or-update-pr.sh --type (feature|fix|hotfix) --title "Short description" [--base main] [--issue N] [--milestone "title"] --body-file path`. Pass `--issue N` only when the PR is for that issue (script injects Issue + Development + Milestone). Otherwise omit `--issue`. Write the body file with **sections only** (no intro line, no Issue/Development/Milestone). Title is auto-prefixed.
- If the user's request is vague, ask for title, body content, and **which issue this PR is for** (e.g. "Which issue number does this PR close, or is there none?").

### 3. Show preview

Present a clear **preview** of the PR:

```markdown
## Preview: Pull request

- **Title:** ✨ [Feature] … | 🐛 [Fix] … | 🚑 [Hotfix] … (emoji + prefix, exactly one)
- **Base:** main ← **Head:** feature/lint-setup (or current branch name)
- **Body:** sections only; if an issue was confirmed, say "Linked issue: #N" in the preview (script will add Closes #N and set Development/Milestone when run with --issue N)
```

Summarize: "I will create or update the PR from `HEAD` into `main` with this title and body. Say **yes** or **go ahead** to apply, or tell me what to change."

### 4. Wait for confirmation

- **Do not** run `create-or-update-pr.sh` until the user explicitly confirms. Only phrases like **"yes"**, **"go ahead"**, **"do it"**, **"confirm"**, or **"looks good"** after seeing the preview count as confirmation. Phrases like "update this PR" or "create the PR" are requests to do the workflow, not confirmation — you must show the preview first and then wait for a separate yes.
- If they request changes, update the draft and show the preview again; repeat until they confirm.

### 5. Create or update only after confirmation

Only proceed to this step after the user has replied to the preview with an explicit yes (e.g. "yes", "go ahead", "do it"). Once they confirm:

1. Ensure the branch is pushed (if the repo uses a remote): `git push -u origin HEAD` or equivalent, if not already pushed.
2. **Write the body to a file** — **sections only**: ## 📝 Description, ## 📋 What changed, ## 🌟 Impact, etc. Do not include the template's intro line or Issue/Development/Milestone in the file. Write to **`.cursor/context/`** only (per [agent-context](.cursor/rules/agent-context.mdc)), e.g. `.cursor/context/pr-body-draft.md`. If the PR is for an issue, pass `--issue N` and the script will inject Issue + Development + Milestone.
3. Run the script with that body file (and `--issue N` only when the PR is for that issue). When `--issue N` is used, the script injects Issue line + **Development:** + **Milestone** from state:

   ```bash
   bash .cursor/scripts/create-or-update-pr.sh --type feature --title "Add linting for X" --base main --issue 7 --body-file .cursor/context/pr-body-draft.md
   ```
   Omit `--issue N` if there is no linked issue. Use `--milestone "Title"` only to override the milestone from state.

4. **Delete the body file** after the script succeeds — remove the file you passed to `--body-file` (e.g. `.cursor/context/pr-body-draft.md`) so it does not remain in the repo.

5. Share the PR URL from the command output.

---

## Reference

| What        | How |
| ----------- | --- |
| Title format| **Emoji + prefix** then short title. ✨ [Feature], 🐛 [Fix], 🚑 [Hotfix]. Example: `✨ [Feature] Add linting for X`. |
| Body templates| `.github/PULL_REQUEST_TEMPLATE/` — **feature.md**, **fix.md**, **hotfix.md** for section structure. Body file = **sections only** (## 📝 Description, ## 📋 What changed, etc.). Do not include the template's intro line or Issue/Development/Milestone; script injects them with --issue N when needed. |
| Create or update PR | Write body to a file (sections only); run `create-or-update-pr.sh --type X --title "..." [--issue N] --body-file path`. Omit --issue unless PR is for that issue; then script injects Issue + Development + Milestone. |
| Link issues | Only when the PR is **for** that issue. Use `Closes #N` or `Relates to #N` in body and pass `--issue N` only then; otherwise omit — do not add an issue link unrelated to the PR. See [tasks-and-github](.cursor/rules/tasks-and-github.mdc). |
| Dependencies| GitHub CLI (gh) — see README → Project agent dependencies ([agent-dependencies](.cursor/rules/agent-dependencies.mdc)) |
| Rules | [agent-scripts](.cursor/rules/agent-scripts.mdc) · [agent-dependencies](.cursor/rules/agent-dependencies.mdc) · [agent-context](.cursor/rules/agent-context.mdc) |

---

## Checklist

- [ ] Synced (`sync-github-tasks.sh`) so state.json is current (for Development link and milestone when using --issue).
- [ ] Branch and base confirmed; commits pushed if needed.
- [ ] Linked issue established (user confirmed or clear from branch/commits); title and body drafted; --issue N passed only when PR is for that issue.
- [ ] Preview shown to the user (full body content).
- [ ] User has confirmed.
- [ ] Body written to a file (sections only; no intro line, no Issue/Development/Milestone); script run with `--body-file` (and `--issue N` only when the PR is for that issue).
- [ ] Body file deleted after create/update succeeds (e.g. remove `.cursor/context/pr-body-draft.md`).
- [ ] PR URL shared.
