# the-project

## Project agent dependencies

Tools required for the agent or scripts under `.cursor/` (see [agent-scripts](.cursor/rules/agent-scripts.mdc)):

| Tool                                                              | Purpose                                                                                                                                                              | Setup                                                    |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **[Git](https://git-scm.com/)**                                   | Used by `.cursor/scripts/sync-github-tasks.sh` to get repo from `git remote origin`.                                                                                 | [Install Git](https://git-scm.com/downloads)             |
| **[GitHub CLI (gh)](https://cli.github.com/manual/installation)** | Used by `sync-github-tasks.sh`, `create-or-update-pr.sh` (create/update PRs), and other scripts. Use **gh 2.40+** to avoid Projects (classic) GraphQL errors when editing PRs. | [Install gh](https://cli.github.com/manual/installation) |
| **[jq](https://jqlang.github.io/jq/download/)**                   | Used by `sync-github-tasks.sh`, `update-story-bodies.sh`, and `update-task-bodies.sh` (--json) to process JSON.                                                      | [Download jq](https://jqlang.github.io/jq/download/)     |
