---
name: check-and-update-task-ac
description: Check and update a task's acceptance criteria. Task from PR/branch; agent checks the branch against each AC and suggests status; you see current (issue) + suggested (agent) and confirm which to mark done. Requires sync, user confirmation before any issue update.
---

# Check acceptance criteria and update task

Use this skill when the user wants to **check and update a task’s acceptance criteria**. **Get the task** from the current branch’s PR or branch name. **Check the branch**: for each AC, infer from the repo (files, README, git) whether it’s done, not done, or unclear. **Present**: show **current status** (what’s in the issue) and **agent suggested status** side by side. User confirms which to mark done; then **update the task** and, if all AC are done, offer the PR. Do not update the issue until the user has confirmed. Scripts: `.cursor/scripts/sync-github-tasks.sh`, `.cursor/scripts/update-task-bodies.sh`. Related: [update-story-or-task](.cursor/skills/update-story-or-task/SKILL.md), [create-or-update-pr](.cursor/skills/create-or-update-pr/SKILL.md), [tasks-and-github](.cursor/rules/tasks-and-github.mdc).

---

## Workflow (8 steps)

### 1. Sync all tasks

Run so `.cursor/context/tasks/state.json` is current:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

If sync fails (e.g. `gh` auth), stop and ask the user to fix it. Then continue.

### 2. Get the task from the PR or branch

- **Current branch:** `git branch --show-current`.
- **PR for this branch:** `gh pr view` (or `gh pr list --head BRANCH --json number,body -q '.[0].body'`). Parse the PR body for an issue reference: `Closes #N`, `Fixes #N`, `#N`, or a GitHub issue URL. The first number found is the **task number**.
- **If there is no PR or no issue in the body:** try the branch name (e.g. `feature/task-7` → 7). If still unknown, ask the user: “Which task number (or issue link) should I update?”
- **TASK_NUM** = that number.

### 3. Load task and check the branch against each AC

- In `.cursor/context/tasks/state.json`, find `issues[]` where `number == TASK_NUM` and get `body`. Extract **## ✅ Acceptance Criteria** (from that heading until the next `---`). Parse lines `- [ ] …` / `- [x] …` as AC items. Note **current status** for each (done = `- [x]`, not done = `- [ ]`).
- **Check the branch** against each AC: use the repo (file names, key files, README, `.cursor/`, config, `package.json`), and optionally `git log -5 --oneline`, `git diff main --stat` (or appropriate base). For each criterion decide **agent suggested status**: **Done** (strong evidence), **Not done** (clearly missing), or **Unclear** (needs user input). Do not change the issue yet.

### 4. Present current status and agent suggested status

Show a single table (or equivalent) with **both** dimensions so the user can compare. Use **visual markers** for both columns:

| # | Current (issue) | Agent suggests | Criterion |
|---|-----------------|----------------|-----------|
| 1 | ✅ Done         | ✅ Done        | Project runs locally… |
| 2 | ☐ Not done      | ✅ Done        | `npx expo start` works… |
| 3 | ☐ Not done      | ◐ Unclear      | Agent structure… |
| 4 | ☐ Not done      | ☐ Not done     | App runs in dev mode… |

- **Current (issue):** ✅ Done or ☐ Not done (from the task body).
- **Agent suggests:** ✅ Done, ☐ Not done, or ◐ Unclear (from step 3). Keep this column visual so it’s easy to scan.

Keep the table scannable. If you have a short evidence note for “Agent suggests”, you can add it in parentheses or a final column.

### 5. Ask the user which AC to mark done

Ask: **“Which criteria should I mark done? (e.g. ‘2 and 3’, ‘all’, or list by number. You can follow the agent suggestion or override.) I’ll update the task once you confirm.”** Do not change the issue until they confirm.

### 6. User confirms

- If the user **specifies** which AC are done (e.g. “2 and 3”, “all”), treat that as the list to mark done. If they need to correct, adjust and ask again until clear.
- Once they **confirm** (e.g. “yes”, “go ahead”, “update”): proceed to step 7. Do not update the issue before explicit confirmation.

### 7. Update the task’s acceptance criteria

Build the **new Acceptance Criteria** block: same lines as current, but change the agreed items from `- [ ]` to `- [x]`. Keep the rest of the body unchanged.

- Write the new AC block to a file under `.cursor/context/` (e.g. `.cursor/context/task-N-ac.md`).
- Update the task **only** with the acceptance criteria field:

```bash
bash .cursor/scripts/update-task-bodies.sh TASK_NUM --acceptance-criteria-file .cursor/context/task-N-ac.md
```

- **Remove the temporary file** after the script succeeds: delete `.cursor/context/task-N-ac.md`.
- Confirm to the user: “Task #N updated; these criteria are now marked done: …”

### 8. If everything is done → redirect to PR

If **all** acceptance criteria for the task are now `- [x]`:

- Tell the user the task is fully done.
- **Redirect to the PR:** “You can open or update the PR and merge when ready. Should I create or update the PR for this branch?” If yes, follow the [create-or-update-pr](.cursor/skills/create-or-update-pr/SKILL.md) skill (preview, confirm, then run the script). Otherwise give the PR link if one exists: `gh pr view --web` or list PRs for the branch.

If not all AC are done, say what’s left and that they can run this flow again after more work (e.g. after deploy).

---

## Reference

| What | Where |
|------|--------|
| Sync | `bash .cursor/scripts/sync-github-tasks.sh` |
| PR for current branch | `gh pr view` or `gh pr list --head BRANCH --json body -q '.[0].body'`; parse for `#N`, `Closes #N`, issue URL |
| Task body / AC | `.cursor/context/tasks/state.json` → `issues[]` with `number`, `body`; parse `## ✅ Acceptance Criteria` |
| Update task AC only | `bash .cursor/scripts/update-task-bodies.sh TASK_NUM --acceptance-criteria-file path` |
| Update task skill | [update-story-or-task](.cursor/skills/update-story-or-task/SKILL.md) |
| Create/update PR | [create-or-update-pr](.cursor/skills/create-or-update-pr/SKILL.md) |
| Agent context | Previews/temp files under `.cursor/context/` per [agent-context](.cursor/rules/agent-context.mdc) |

---

## Checklist

- [ ] Synced tasks (step 1).
- [ ] Got task number from PR body or branch (step 2); if missing, asked user.
- [ ] Loaded task and checked branch against each AC; assigned agent suggested status (Done / Not done / Unclear) (step 3).
- [ ] Presented table: current status (issue) + agent suggested status for each criterion (step 4).
- [ ] Asked user which criteria to mark done (step 5).
- [ ] User confirmed (step 6).
- [ ] Updated task via `update-task-bodies.sh` (step 7).
- [ ] If all AC done, offered to create/update PR or shared PR link (step 8).
