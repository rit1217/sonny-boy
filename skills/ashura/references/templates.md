# Ashura templates

## state.md
```markdown
# Ashura run <run>
phase: setup | decompose | running | integrate | paused | closed
mode: nested | flat
working: <branch>
top: <abs path>
real_stack_lock: none | <Tn>

## Goal
<2 lines: goal restated; smallest change>

## Environment
os: <Darwin | Linux | WSL | Windows-GitBash>
python: <abs path>
tests: <command(s)>
e2e: <boot recipe or none>
gh: ok | not authed | missing
origin/<working>: present | missing | no remote
graphify: yes | no
document-update: yes | no

## House rules
- <rule copied from CLAUDE.md / memory>

## Subtasks
| T | title | branch | base | wt | lead id | status | PR |
|---|---|---|---|---|---|---|---|

## Queue
<subtasks waiting for a lead slot or a parent>

## Question queue
<FIFO: Tn, question id, asked yes/no>
```

## decisions.tsv (header)
```
ts	phase	decision	why	evidence	result
```

## project.md (optional, per repo: `<top>/.claude/ashura/project.md`)
```markdown
# Ashura project facts
python: <path relative to top or absolute, e.g. .venv/bin/python>
tests: <unit/integration command, e.g. "<python> -m pytest -q">
frontend_dir: <e.g. frontend, or none>
frontend_install: <e.g. npm ci>
e2e_mock: <how to run Playwright mock lane, e.g. "cd frontend && PW_PORT=<vite> npx playwright test">
real_stack:
  services: <e.g. "docker start my-db" — Ashura asks the user to run it>
  backend: <e.g. "<python> -m uvicorn app.main:app --port <backend>">
  frontend: <e.g. "cd frontend && VITE_API_TARGET=http://localhost:<backend> npx vite --port <vite>">
  health: <e.g. "curl -sf http://localhost:<backend>/health">
notes: <repo-specific traps>
```
`<backend>` = `port_base`, `<vite>` = `port_base + 1`.

## Lead kickoff
```
You are ashura-lead for <Tn> "<title>" in run <run>.
mode: new | resume
worktree: <wt abs path>
branch: <branch>
base_ref: <working or parent branch>
task_dir: <task_dir abs path>
state: <run_dir>/state.md            (read Environment + House rules)
subtask: <run_dir>/subtasks.md#<Tn>  (goal, done evidence, file boundary, e2e flag)
qa_log: <task_dir>/qa.md
port_base: <n or none>
Return only your STATUS block (first line STATUS: <TOKEN>, ≤15 lines).
```

## Status board
```
| T | title | phase | status | waiting on |
|---|---|---|---|---|
```
Phase ∈ plan, red, green, verify, review, verified, PR, merged, paused, failed.

## PR body (written by verifier to `<task_dir>/pr-body.md`)
```markdown
## Why
<1–3 lines: problem and goal>

## What changed
- <bullet per meaningful change>

## Scope
Subtask <Tn> of Ashura run <run>. Boundary: <globs>. Out of scope: <items>.

## Tradeoffs
<what was chosen over what, and why>

## Blast radius
<callers / modules / users affected; risk level>

## Verification
- <done evidence command> → <result>
- <test command> → <N passed>
- AC1 → <test id / evidence>
```
≤40 lines. End with the attribution line from House rules.
