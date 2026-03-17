# the-project

Expo/React Native app. Use the **CLI** for setup and version checks — **doctor** runs Node/npm/nvm checks; **install** sets up nvm, config, Node from [.nvmrc](.nvmrc), and runs `npm install`. Use `--no-banner` for agents/CI.

## CLI

Run from the repo root: `npm run cli` or `bash scripts/cli.sh`. Then choose **doctor** or **install**, or pass the command: `npm run cli -- doctor` / `npm run cli -- install`.

## Required versions

- **Node.js:** 22.22.1 (LTS Jod). Use the version in the repo: `nvm use` (or `nvm install` if needed) — reads [.nvmrc](.nvmrc). Enforced via `package.json` `engines` and [.npmrc](.npmrc) `engine-strict=true` (npm will fail if Node doesn’t match).

**Test that engine-strict is working:** switch to a different Node (e.g. `nvm use 20`) and run `npm install` — it should fail with `EBADENGINE`. Then `nvm use` (or `nvm use 22.22.1`) and `npm install` should succeed.

## Project agent dependencies

Tools required for the agent or scripts under `.cursor/` (see [agent-scripts](.cursor/rules/agent-scripts.mdc)):

| Tool                                                              | Purpose                                                                                                                                                                        | Setup                                                    |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| **[Git](https://git-scm.com/)**                                   | Used by `.cursor/scripts/sync-github-tasks.sh` to get repo from `git remote origin`.                                                                                           | [Install Git](https://git-scm.com/downloads)             |
| **[GitHub CLI (gh)](https://cli.github.com/manual/installation)** | Used by `sync-github-tasks.sh`, `create-or-update-pr.sh` (create/update PRs), and other scripts. Use **gh 2.40+** to avoid Projects (classic) GraphQL errors when editing PRs. | [Install gh](https://cli.github.com/manual/installation) |
| **[jq](https://jqlang.github.io/jq/download/)**                   | Used by `sync-github-tasks.sh`, `update-story-bodies.sh`, and `update-task-bodies.sh` (--json) to process JSON.                                                                | [Download jq](https://jqlang.github.io/jq/download/)     |

## Agent skills

Scripts and skills under `.cursor/` support task/PR workflows:

- **Check task AC and update issue** — Sync tasks → task is derived from PR description or branch (e.g. Closes #7) → you confirm which AC are done → task body is updated; if all AC done, agent can create/update the PR. Skill: `.cursor/skills/check-and-update-task-ac/SKILL.md`; uses `sync-github-tasks.sh`, `update-task-bodies.sh`, `gh pr view`.
- **Create or update PR** — `.cursor/skills/create-or-update-pr/SKILL.md`
- **Create/update story and tasks** — `.cursor/skills/create-story-and-tasks/SKILL.md`
- **Update story or task body** — `.cursor/skills/update-story-or-task/SKILL.md`

See [AGENTS.md](AGENTS.md) for rules (scripts, context, tasks & GitHub).
