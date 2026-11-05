# Ashura

Ashura is a Claude Code plugin: a head-of-team orchestrator on top of a 5-agent dev pipeline
(planner → coder → advisor → tester → reviewer). It does what a single pipeline cannot:

- splits one or many requirements into subtasks (`decomposer`);
- gives each subtask its own git worktree, branch and lead agent (`ashura-lead`), up to 3 in
  parallel;
- relays every question to you as a question box labelled `[Tn · title]`, queuing overflow;
- asks you to approve acceptance criteria and the test design per subtask, then builds tests
  first (red → green);
- runs a fresh `verifier` before each PR and opens one PR per subtask into your **working
  branch**, never `main`. You merge.

Principles adapted from pstack (Lauren Tan, `cursor/plugins/pstack`) are in
`skills/ashura/references/principles.md`.

## Install

In Claude Code:

```
/plugin marketplace add https://github.com/juliusbrussee/caveman.git
/plugin marketplace add https://github.com/rit1217/ashura-skills.git
/plugin install caveman@caveman
/plugin install mattpocock-skills@claude-plugins-official
/plugin install ashura@ashura-skills
```

`ashura` depends on `caveman@caveman` (terse output; every agent preloads it) and
`mattpocock-skills@claude-plugins-official` (the planner's grilling skills). Install them
yourself as above: Claude Code 2.1.318 did not install them automatically, and `ashura` reports
"failed to load" until both are present (`/plugin list` shows the status). Start a new session
after installing.

To work on Ashura itself, add your local clone instead (`/plugin marketplace add <path-to-clone>`).

## Commands

| Command | What |
|---|---|
| `/ashura:ashura <requirements>` | new run: decompose, build in worktrees, open PRs |
| `/ashura:ashura status` | status board, restack children whose parent PR merged |
| `/ashura:ashura pause` / `resume [run]` | pause safely; resume in a fresh session from files |
| `/ashura:dev-pipeline <requirement>` | the plain single-requirement pipeline in the current checkout |

Agents are named `ashura:planner`, `ashura:coder`, and so on, so they never collide with agents
you already have in `~/.claude/agents/`.

Per repo, Ashura writes run state to `<repo>/.claude/ashura/<run>/` and worktrees to
`<repo>/.claude/worktrees/`, and adds both to `.git/info/exclude`. Repo-specific facts (python
path, test commands, how to boot the real stack for e2e) go in an optional
`<repo>/.claude/ashura/project.md`; without it Ashura probes and asks once. Template in
`skills/ashura/references/templates.md`.

## Permissions (read this once)

Claude Code asks before it edits a file or runs a command, unless a rule or mode says yes.
Ashura runs many agents in the background, and each one's prompts show up in your main session.
Two ways to cut that down:

1. **Accept-edits mode** (recommended for a run). Press Shift+Tab in the session until the
   footer shows "accept edits", then start `/ashura:ashura`. File edits are approved
   automatically, for Ashura and every agent it starts, because agents inherit the session's
   mode. Commands still ask unless allowlisted. Files outside the project still ask.
2. **Allowlist** for routine commands (git add/commit, `git worktree add`, test runners,
   graphify, `gh pr view`):

   ```bash
   scripts/setup-permissions.sh            # adds rules to ~/.claude/settings.json (backs it up first)
   scripts/setup-permissions.sh --dry-run  # just count what would be added
   ```

   `git push`, `gh pr create/edit`, `git worktree remove` and branch deletion are left out on
   purpose, so they always ask. Ashura also asks you in chat before each of them.

A plugin cannot set modes or rules itself: Claude Code ignores `permissionMode` in plugin agents
and drops permission rules from plugin settings. That is why both steps are yours.

## Platforms and prerequisites

Runs wherever Claude Code runs locally (CLI, desktop app, IDE extension) on macOS, Linux, WSL and
Windows. Not on Claude Code on the web or claude.ai chat.

| | macOS | Linux / WSL | Windows (no admin needed) |
|---|---|---|---|
| git | `xcode-select --install` | `sudo apt install git` | Git for Windows (Claude Code needs Git Bash anyway) |
| gh (opening PRs) | `brew install gh` | `sudo apt install gh` | portable zip from github.com/cli/cli/releases, add to PATH |
| node + npx (only for web e2e) | `brew install node` | `sudo apt install nodejs npm` or nvm | nodejs.org zip or nvm-windows |

Then once per machine: `gh auth login`.

## Web e2e (optional)

Only needed when a requirement changes a web UI. When it does, Ashura adds a `T0 e2e harness`
subtask that adds Playwright Test to that repo and installs a browser
(`npx playwright install chromium`; on Linux/WSL `npx playwright install --with-deps chromium`,
which needs sudo). The specs it commits are the proof; nothing global is required.

**Optional live probe.** If you also install the Playwright MCP server, the `e2e-tester` agent
clicks through the changed screen and saves screenshots to the subtask folder. Without it, that
step is skipped and reported as skipped.

```bash
# macOS / Linux / WSL
claude mcp add --scope user playwright -- npx -y @playwright/mcp@0.0.84 --headless
# Windows (native)
claude mcp add --scope user playwright -- cmd /c npx -y @playwright/mcp@0.0.84 --headless
```

Its tools then load in every session, not only for the e2e-tester.

## Layout

| Path | What |
|---|---|
| `.claude-plugin/` | `plugin.json` (plugin + dependencies), `marketplace.json` (this repo as a marketplace) |
| `skills/ashura/` | orchestrator skill + `references/` (principles, templates) |
| `skills/dev-pipeline/` | single-requirement pipeline skill |
| `agents/` | 10 agents: planner, coder, advisor, tester, reviewer, ashura-lead, decomposer, verifier, integrator, e2e-tester |
| `scripts/setup-permissions.sh` | optional allowlist setup |

Models: Opus for planning and judgement (Ashura, ashura-lead, planner, advisor, reviewer,
decomposer); Sonnet for writing code or tests (coder, tester, e2e-tester, verifier, integrator).

The first commit holds the 5 original pipeline agents and `/dev-pipeline` unchanged; later
commits show each change as a diff.
