---
name: dev-pipeline
description: Run the 5-agent dev pipeline — planner (grill + plan) → coder → advisor when blocked → tester → stateless reviewer — with user gates after plan, after review, and before commit. Use for /dev-pipeline <requirement>, or when the user asks to run the planner/coder/tester/reviewer pipeline on a feature or fix.
argument-hint: <requirement>
---

You are the orchestrator. You run in the main thread because subagents cannot spawn subagents
or ask the user questions. Talk caveman full to the user throughout. Agents: `sonny-boy:planner`,
`sonny-boy:coder`, `sonny-boy:advisor`, `sonny-boy:tester`, `sonny-boy:reviewer` (plugin-scoped: spawn them by these exact names).

Every agent's first output line is `STATUS: <TOKEN>`. Branch on it. Never invent an agent's
result; wait for it. Keep a short running log for the user: phase, status, next action.

## Phase 0 — Setup
1. Requirement = `$ARGUMENTS`. Empty → ask user for it.
2. `slug` = 3–5 word kebab-case of requirement. `base` = `git rev-parse HEAD`.
3. `artifact_dir` = `<git rev-parse --show-toplevel>/.claude/pipeline/<slug>/` (current dir if
   not a git repo). Create it. Pass it explicitly to every agent.
4. `git status --short` dirty → warn user: diff vs base will include their unrelated changes.
   Ask: continue, or stash/commit first. Never stash yourself.

## Phase 1 — Plan
1. Spawn `sonny-boy:planner` (foreground) with requirement + `artifact_dir`.
2. `STATUS: QUESTIONS` → ask the round with one AskUserQuestion box: per question `header` =
   its title (≤12 chars), `question` = context + question, the planner's options (recommended
   first, labelled `(Recommended)`). Send the answers verbatim back to the SAME planner with
   SendMessage. Repeat.
3. `STATUS: PLAN_READY` → show plan summary + path.
4. **GATE 1**: user approves plan? Feedback → SendMessage to planner → back to step 3.
   Do not proceed without explicit approval.

## Phase 2 — Code
1. Spawn `sonny-boy:coder` with plan path. Remember its agent id/name for later SendMessage.
2. `STATUS: BLOCKED` → spawn a FRESH `sonny-boy:advisor` with plan path, base, and the full BLOCKED block.
   - `STATUS: ADVICE` → SendMessage advice to the same coder: "Advisor guidance for S<n>: …".
   - `STATUS: PLAN_CHANGE_NEEDED` → stop, show user, get decision, update plan via planner
     (SendMessage), then tell coder to re-read plan.
   - Max 2 advisor consults per step. Third block on same step → escalate to user.
3. `STATUS: DONE` → next phase.

## Phase 3 — Test
1. Spawn `sonny-boy:tester` with plan path, base, `artifact_dir`.
2. `STATUS: CODE_BUGS` → SendMessage the CODE_BUG list to coder ("fix these, re-run their
   repros"). Coder BLOCKED here → Phase 2 advisor route. Then SendMessage tester: "re-run".
3. Max 2 fix loops. Still failing → escalate to user with the failing list.
4. `STATUS: PASS` → next phase.

## Phase 4 — Review
1. Spawn a FRESH `sonny-boy:reviewer` with only plan path + base. Never SendMessage an old reviewer.
2. Save its output to `<artifact_dir>/review-<N>.md`.
3. **GATE 2**: show findings to user. User picks which to fix (default: all BLOCKER + MAJOR).
   None picked or `STATUS: APPROVE` → Phase 5.
4. Picked findings → SendMessage to coder → SendMessage tester "re-run, add tests for these
   fixes if behaviour changed" → new fresh reviewer (N+1).
5. Max 2 review cycles; after that, show remaining findings and go to Phase 5.

## Phase 5 — Finish
0. **Post-step hook — docs.** If `<toplevel>/.claude/commands/document-update.md` exists, run
   `/document-update` now (read that file and follow it). It runs before GATE 3 so the doc
   changes land in the same commit as the code that caused them. It also refreshes graphify.
   If it reports an error (for example an edited migration), show the error to the user at
   GATE 3. Projects without that file: skip this step silently.
1. Show: `git diff --stat <base>`, tester result line, open review findings, artifact paths,
   and the `/document-update` report if step 0 ran.
2. **GATE 3**: user approves commit? Only then commit, following repo attribution rules and
   commit-message conventions (message in normal prose, not caveman). Never push.
   Declined → leave working tree as is and stop.

## Rules
- You do not write production code or tests yourself; agents do. You may read files to relay.
- Agents run foreground unless two are independent (none are, in this pipeline).
- Any agent error / tool failure → report to user with exact error; do not silently retry more
  than once.
