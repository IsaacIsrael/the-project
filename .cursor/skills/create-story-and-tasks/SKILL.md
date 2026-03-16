---
name: create-story-and-tasks
description: Creates or extends GitHub story/task hierarchy. Use when the user wants to create a new story with related tasks, add tasks to an existing story, or scaffold story/task structure. Requires preview and user confirmation before running create scripts.
---

# Create story and tasks / Add tasks to a story

Use this skill when the user wants to **create a new story and its tasks** or **add tasks to an existing story**. **Do not run any create script until the user has seen a preview and confirmed.** Scripts: `.cursor/scripts/create-story.sh`, `.cursor/scripts/create-task.sh`. Scripts are agent-only ([agent-scripts](.cursor/rules/agent-scripts.mdc)); dependencies (e.g. `gh`) in README ([agent-dependencies](.cursor/rules/agent-dependencies.mdc)); any preview or context you persist goes in `.cursor/context/` ([agent-context](.cursor/rules/agent-context.mdc)).

- **New story + tasks** → follow "Workflow: New story and tasks" below.
- **Add tasks to existing story** → follow "Workflow: Add tasks to existing story" below.

---

## Workflow: New story and tasks

### 0. Sync tasks first

Run so `.cursor/context/tasks/state.json` and `TASKS.md` are up to date before drafting or creating:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

Then proceed. This avoids working with stale story/task numbers or hierarchy.

### 1. Discuss and draft

- **Story title index (the number in the title):** Read `.cursor/context/tasks/state.json`. For each **story** (each id in `hierarchy.roots`), get `hierarchy.byNumber["<id>"].title` (e.g. `"[Store 0] Definitions"`, `"[Story 1] Linting"`, `"[Story 5] Deploy"`). Parse the **number** from that title (the digit after “Store” or “Story”, e.g. 0, 1, 2, 3, 4, 5). Take the **maximum** of those numbers, then use **max + 1** for the new story’s title. Use the correct spelling **`[Story N]`** for new stories (e.g. if max is 5, use `[Story 6] Short name`). Existing issues may still show the old typo “Storie” until their titles are updated on GitHub.
- **Task title format:** `[Task <storyNum>.<taskIndex>] Short name`. **Story number** = parent story's number (from its title, e.g. 0, 1, 6). **Task index** = highest existing task number under that story + 1: from `state.json`, get `hierarchy.byNumber["<parent_issue_num>"].children`; for each child id get `hierarchy.byNumber["<id>"].title`, parse the part after the dot in `[Task X.Y]` (e.g. 0.3 → Y = 3). Next index = max Y + 1. For a **new story** with no tasks yet, use 0, 1, 2, … in order (first task `[Task N.0]`, second `[Task N.1]`, etc.).
- Gather or propose: **story** (title with that index, description, objective, acceptance criteria) and **each task** (title in `[Task N.M]` form, description, objective, scope, technical notes, acceptance criteria, references).
- If the user’s request is vague, ask for missing pieces (e.g. story short name, how many tasks, what each task should cover).
- Draft the full content in the conversation; do not create issues yet.

### 2. Show preview

Present a clear **preview** of what will be created. Use a format like:

```markdown
## Preview: Story

- **Title:** [Story N] …
- **Description:** …
- **Objective:** …
- **Acceptance criteria:** …

## Preview: Tasks (parent = new story)

**Task 1** — `[Task N.0] …`

- **Title:** [Task N.0] …
- **Description:** …
- **Objective:** …
- **Scope:** …
- **Technical notes:** …
- **Acceptance criteria:** …
- **References:** …

**Task 2** — `[Task N.1] …`

- **Title:** [Task N.1] …
…
(N = new story number; first task .0, second .1, etc.)
```

Summarize: “I will create 1 story and N tasks. Say **yes** or **go ahead** to create them, or tell me what to change.”

### 3. Wait for confirmation

- **Do not** run `create-story.sh` or `create-task.sh` until the user explicitly confirms (e.g. “yes”, “looks good”, “go ahead”, “create them”).
- If the user requests changes, update the draft and show the preview again; repeat until they confirm.
- If they only comment on one part (e.g. “fix the second task”), update that part and re-show the full preview before asking again.

### 4. Create only after confirmation

Once the user confirms:

1. **Create the story** (repo root):

   ```bash
   bash .cursor/scripts/create-story.sh --title "..." --description "..." --objective "..." --acceptance-criteria "..."
   ```

   Use `--description-file`, `--objective-file`, `--acceptance-criteria-file` for long content. Omit a field to use the script default.

2. **Get the new story issue number** from the `gh issue create` output (URL ends with `/issues/N` → N is the story number).

3. **Create each task** with that parent:

   ```bash
   bash .cursor/scripts/create-task.sh --parent STORY_NUM --title "..." --description "..." ...
   ```

   Replace `STORY_NUM` with the number from step 2. Use `-file` variants for multiline where needed.

4. Optionally run `bash .cursor/scripts/sync-github-tasks.sh` so `.cursor/context/tasks/` reflects the new issues.

## Checklist

- [ ] Tasks synced (`sync-github-tasks.sh`) before drafting.
- [ ] Story and tasks drafted and discussed.
- [ ] Preview shown to the user (story + all tasks).
- [ ] User has confirmed (no scripts run before this).
- [ ] Story created with `create-story.sh`.
- [ ] Story issue number noted.
- [ ] Each task created with `create-task.sh --parent STORY_NUM`.

## Scripts and templates

| What                    | Where                             |
| ----------------------- | --------------------------------- |
| Create story            | `.cursor/scripts/create-story.sh` |
| Create task             | `.cursor/scripts/create-task.sh`  |
| Story template (labels) | `.github/ISSUE_TEMPLATE/story.md` |
| Task template (labels)  | `.github/ISSUE_TEMPLATE/task.md`  |

Tasks are linked via **Parent: #STORY_NUM** in the task body (`--parent`).

**Related rules:** [agent-scripts](.cursor/rules/agent-scripts.mdc) · [agent-dependencies](.cursor/rules/agent-dependencies.mdc) · [agent-context](.cursor/rules/agent-context.mdc)

---

## Workflow: Add tasks to existing story

Use when the user wants to **add one or more tasks** under an **existing** story (e.g. “add two tasks to story #1”, “add a task to the Definitions story”).

### 0. Sync tasks first

Run so `.cursor/context/tasks/state.json` (and thus the story’s current children) is up to date:

```bash
bash .cursor/scripts/sync-github-tasks.sh
```

Then identify the story and show current tasks. Without this, the “current tasks” table may be wrong or missing.

### 1. Identify the story

- **Story number** is required. Get it in one of these ways:
  - **User says the number** (e.g. “add tasks to story 1” or “story #2”) → use that number.
  - **User says the story name/title** → resolve from `.cursor/context/tasks/state.json`: `hierarchy.roots` lists story issue numbers (e.g. `[1,2,3,4,5,6]`); for each root, check `hierarchy.byNumber["<num>"].title` and pick the one that matches (e.g. “Definitions”, “Linting”). Use that number.
  - **From TASKS.md** → stories are usually the top-level bullets; the issue number often appears in the title or link. Match by name and take the number.
- Confirm with the user: “I’ll add these tasks under story #N.” if there could be doubt.

### 2. Discuss and draft tasks

- Gather or propose each **task** (title, description, objective, scope, technical notes, acceptance criteria, references).
- Draft all task content in the conversation; do not create issues yet.

### 3. Show current tasks, then preview new ones

**First**, read `.cursor/context/tasks/state.json` and list the **existing tasks** under that story so the user sees the full picture before adding more.

- From `state.json`: `hierarchy.byNumber["STORY_NUM"].children` is an array of task issue numbers. For each number, get `hierarchy.byNumber["<num>"].title` and `state` (open/closed).
- If the file is missing or stale, suggest running `bash .cursor/scripts/sync-github-tasks.sh` and list what you can from the file.
- **Then** show the preview of the **new** tasks to create.

Use a format like:

```markdown
## Story #STORY_NUM – current tasks (from .cursor/context/tasks/state.json)

| #   | Title                            | State |
| --- | -------------------------------- | ----- |
| 7   | [Task 0.0] Bootstrap the project | open  |
| 8   | [Task 0.1] Interpreters…         | open  |
| …   | …                                | …     |

## Preview: New tasks to create (parent = #STORY_NUM)

**Task 1** — `[Task STORY_NUM.(max+1)] …`

- **Title:** [Task STORY_NUM.(max+1)] … (e.g. if story 1 has tasks 1.0–1.2, next is [Task 1.3] …)
- **Description:** …
- **Objective:** …
- **Scope:** …
- **Technical notes:** …
- **Acceptance criteria:** …
- **References:** …

**Task 2** — `[Task STORY_NUM.(max+2)] …`
…
```

Summarize: “Story #STORY_NUM currently has X tasks (above). I will add N new tasks. Say **yes** or **go ahead** to create them, or tell me what to change.”

### 4. Wait for confirmation

- **Do not** run `create-task.sh` until the user explicitly confirms.
- If they request changes, update the draft, show the preview again, repeat until they confirm.

### 5. Create only after confirmation

Once the user confirms:

1. For **each** task, run (repo root):

   ```bash
   bash .cursor/scripts/create-task.sh --parent STORY_NUM --title "..." --description "..." ...
   ```

   Use the **existing** story number; use `-file` variants for multiline where needed.

2. Optionally run `bash .cursor/scripts/sync-github-tasks.sh` so `.cursor/context/tasks/` reflects the new issues.

### Checklist (add tasks to existing story)

- [ ] Tasks synced (`sync-github-tasks.sh`) so state.json is current.
- [ ] Story number identified and confirmed.
- [ ] Current tasks under the story read from `.cursor/context/tasks/state.json` (hierarchy.byNumber[STORY_NUM].children).
- [ ] New tasks drafted and discussed.
- [ ] Preview shown: **current tasks** table first, then **new tasks** to create (parent #N).
- [ ] User has confirmed.
- [ ] Each new task created with `create-task.sh --parent STORY_NUM`.
