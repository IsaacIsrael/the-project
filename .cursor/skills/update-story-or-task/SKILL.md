---
name: update-story-or-task
description: Updates an existing GitHub story or task (body fields and optionally title). Use when the user wants to change a story's or task's description, objective, acceptance criteria, or other body fields; or rename (title). Requires preview and user confirmation before running update scripts.
---

# Update a story or task

Use this skill when the user wants to **edit an existing story or task** (body content or title). **Do not run any update script or `gh issue edit` until the user has seen a preview and confirmed.** Scripts: `.cursor/scripts/update-story-bodies.sh`, `.cursor/scripts/update-task-bodies.sh`. For **title-only** changes use `gh issue edit <num> --title "..."`. Related: [agent-scripts](.cursor/rules/agent-scripts.mdc) · [agent-dependencies](.cursor/rules/agent-dependencies.mdc) · [agent-context](.cursor/rules/agent-context.mdc) (previews/context → `.cursor/context/`).

- **Update a story** → follow "Workflow: Update a story" below.
- **Update a task** → follow "Workflow: Update a task" below.

---

## Workflow: Update a story

### 0. Sync first

Run so `.cursor/context/tasks/state.json` and issue data are current before resolving the issue or drafting changes:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

### 1. Identify the story and clarify what to change

- **Resolve the issue number:** By **number** (e.g. "update #3", "story 2") or by **name**: read `.cursor/context/tasks/state.json`; stories are in `hierarchy.roots`; for each root id get `hierarchy.byNumber["<id>"].title` and match the user's phrase (e.g. "Linting", "Deploy") to get the issue number.
- **Decide what to update:** **Body fields** (description, objective, acceptance criteria)—only passed fields change; fetch current via `gh issue view N --json body` if needed. **Title** (e.g. fix "Storie" → "Story"): use `gh issue edit N --title "..."`; if both body and title change, run body script first then `gh issue edit`.
- If the request is vague, ask which story and which fields (or paste the new content).

### 2. Show preview

Present a clear **preview** of the update. Show **current** vs **new** for every field (and title) being changed:

```markdown
## Preview: Story #N – updates

**Title** (if changing)
- **Current:** [Story N] Old name
- **New:** [Story N] New name

**Body fields** (only include rows for fields you are changing)

| Field                 | Current (excerpt)     | New (excerpt)        |
| --------------------- | -------------------- | -------------------- |
| Description           | …                    | …                    |
| Objective             | …                    | …                    |
| Acceptance criteria   | - [ ] Old             | - [ ] New             |
```

Summarize: "I will update story #N (title and/or description, objective, acceptance criteria). Say **yes** or **go ahead** to apply, or tell me what to change."

### 3. Wait for confirmation

- **Do not** run `update-story-bodies.sh` or `gh issue edit` until the user explicitly confirms (e.g. "yes", "go ahead", "apply").
- If they request changes, update the draft and show the preview again; repeat until they confirm.

### 4. Run updates only after confirmation



**Body only (one story):**

```bash
bash .cursor/scripts/update-story-bodies.sh ISSUE_NUM --description "..." --objective "..." --acceptance-criteria "..."
```

Use `--description-file`, `--objective-file`, `--acceptance-criteria-file` for multiline.

**Body only (multiple stories):** use JSON (see script help):

```bash
bash .cursor/scripts/update-story-bodies.sh --json '[{"id":1,"description":"..."},{"id":2,"objective":"..."}]'
# or
bash .cursor/scripts/update-story-bodies.sh --json-file .cursor/scripts/stories-update.example.json
```

**Title only or title + body:**

```bash
gh issue edit ISSUE_NUM --title "[Story 3] New short name"
```

If both body and title change, run the body update script first, then `gh issue edit ... --title "..."`.

---

## Workflow: Update a task

### 0. Sync first

Same as story workflow:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

### 1. Identify the task and clarify what to change

- **Resolve the issue number:**
  - By **number**: e.g. "update #8", "task 9" → use that issue number.
  - By **name**: read `.cursor/context/tasks/state.json`. For each story id in `hierarchy.roots`, get `hierarchy.byNumber["<id>"].children` (task ids). For each child id get `hierarchy.byNumber["<id>"].title`. Match the user's phrase to a task title and use that id as the issue number.
- **Decide what to update:**
  - **Body fields:** description, objective, scope, technical_notes, acceptance_criteria, references, parent (story number). Only the fields you pass will change; others stay as-is.
  - **Title:** e.g. renumber to `[Task 1.4] New name`. Use `gh issue edit N --title "..."`. If both body and title change, run the body script first, then `gh issue edit`.
- If the user's request is vague, ask which task and which fields (or paste the new content).

### 2. Show preview

Present a clear **preview** of the update. Show **current** vs **new** for every field (and title) being changed. Use a format like:

```markdown
## Preview: Task #N – updates

**Title** (if changing)
- **Current:** [Task 1.2] Old name
- **New:** [Task 1.4] New name

**Body fields** (only include rows for fields you are changing)

| Field                 | Current (excerpt)     | New (excerpt)        |
| --------------------- | -------------------- | -------------------- |
| Description           | …                    | …                    |
| Objective             | …                    | …                    |
| Scope                 | - [ ] Old             | - [ ] New             |
| Technical notes       | …                    | …                    |
| Acceptance criteria   | …                    | …                    |
| References            | …                    | …                    |
| Parent                | #1                   | #2 (if moving)        |
```

Summarize: "I will update task #N (title and/or body fields). Say **yes** or **go ahead** to apply, or tell me what to change."

### 3. Wait for confirmation

- **Do not** run `update-task-bodies.sh` or `gh issue edit` until the user explicitly confirms (e.g. "yes", "go ahead", "apply").
- If they request changes, update the draft and show the preview again; repeat until they confirm.

### 4. Run updates only after confirmation

**Body only (one task):**

```bash
bash .cursor/scripts/update-task-bodies.sh ISSUE_NUM --description "..." --objective "..." --scope "..." --technical-notes "..." --acceptance-criteria "..." --references "..." --parent STORY_NUM
```

Use `-file` variants for multiline.

**Body only (multiple tasks):** use JSON:

```bash
bash .cursor/scripts/update-task-bodies.sh --json '[{"id":8,"description":"..."},{"id":9,"scope":"..."}]'
# or
bash .cursor/scripts/update-task-bodies.sh --json-file path/to/updates.json
```

**Title only or title + body:**

```bash
gh issue edit ISSUE_NUM --title "[Task 1.4] New short name"
```

If both body and title change, run the body update script first, then `gh issue edit ... --title "..."`.

---

## Reference

| What              | Where |
| ----------------- | ----- |
| Story body script | `.cursor/scripts/update-story-bodies.sh` |
| Task body script  | `.cursor/scripts/update-task-bodies.sh` |
| Story JSON keys   | id, description, objective, acceptance_criteria |
| Task JSON keys    | id, parent, description, objective, scope, technical_notes, acceptance_criteria, references |
| Example JSONs     | `.cursor/scripts/stories-update.example.json`, `tasks-update.example.json` |
| Title             | `gh issue edit <num> --title "..."` (not in body scripts) |
| Rules             | [agent-scripts](.cursor/rules/agent-scripts.mdc) · [agent-dependencies](.cursor/rules/agent-dependencies.mdc) · [agent-context](.cursor/rules/agent-context.mdc) |

---

## Checklist

- [ ] Synced (`sync-github-tasks.sh`) so issue numbers/titles are current.
- [ ] Issue identified (by number or name from state.json).
- [ ] Changes drafted; preview (current vs new) shown.
- [ ] User has confirmed.
- [ ] Body updated via script (if needed); title updated via `gh issue edit` (if needed).
