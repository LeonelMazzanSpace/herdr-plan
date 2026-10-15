---
name: executing-herdr-plans
description: Use when executing an approved implementation plan by orchestrating independent Claude Code workers in Herdr panes (one git worktree per task), or when resuming, checking status of, or closing such a run
---

# Executing Herdr Plans

## Overview

One orchestrator session runs a plan written with **writing-herdr-plans**. It runs the plan wave by wave: each task goes to a fresh Claude Code worker in its own Herdr pane and git worktree, is checked by an independent reviewer, and is integrated by the orchestrator with a full gate after every merge.

**Core principle:** a worker's report is a claim, not evidence. A task is `completed` only after it has been implemented, reviewed, integrated and verified, and the orchestrator has checked each step itself.

**REQUIRED BACKGROUND:** the `herdr` and `herdr-agent-orchestration` skills (CLI and lifecycle states), superpowers:verification-before-completion, superpowers:receiving-code-review. Use superpowers:systematic-debugging for any red gate.

`<skill-dir>` below is this skill's base directory (shown when the skill loads, e.g. `~/.claude/skills/executing-herdr-plans`). Always call the scripts by that absolute path, because you run from COORDINATION_ROOT.

**Herdr agent names** must be unique among live agents:
- implementer: `t0NN`;
- reviewer: `t0NN-r<N>` (N = review attempt);
- fresh fix worker: `t0NN-f<N>` (N = fix attempt).

The `-n` label is only Claude's display name.

## Roles

- **Orchestrator (you):**
  - owns T-000, worktrees, databases, launches, merges into the coordination branch, gates and all Git;
  - is the only writer of `SCRATCHPAD.md` and the vault.
- **Worker:** executes one package, writes one report and never orchestrates.
  - Workers may use internal subagents for analysis; those never replace Herdr workers.
- **Decide routine technical questions yourself** and record them as D-numbers. Ask the user only for:
  - product decisions that change scope;
  - destructive or security-sensitive actions;
  - push, PR or merges into shared branches.

## Preflight (once per run)

1. `test "$HERDR_ENV" = 1`. If it fails, record the blocker and ask the user to start the orchestrator inside a Herdr pane.
2. Check versions and syntax:
   - `herdr --help`, `herdr agent`, `herdr integration status` (expect `claude: current`);
   - `claude --help` for `--model`, `--permission-mode`, `--add-dir`, `-n`.
3. Read the scratchpad (`scratchpad-template.md` if missing), the plan and its summary. Confirm the vault MCP is connected before reading the vault notes the tasks name.
   - If the MCP fails: tell the user, record the blocker, and continue only the tasks that do not depend on vault content. Queue the vault updates in the scratchpad.
   - Never fall back to reading vault files from disk.
4. Create the report dir: `mkdir -p -m 700 ~/.cache/herdr-reports/<run-id>`. Packages, reports, reviews, fix files and vault excerpts (`<task>.vault.md`) all live there.
5. Check that the plan has the writing-herdr-plans headings: build the first worker task's package (T-001) with `make-package.sh`. The script fails and names any missing section.
6. **Permission mode.** Workers need a write-capable mode.
   - Launching with `--permission-mode auto` may be denied by the permission classifier. If so, ask the user once to authorize it and record the answer as a D-number.
   - If the user refuses, ask which write-capable mode they approve (e.g. `acceptEdits`, approving commands in each pane). Never switch to bypass flags.
7. **Keep the machine awake.** Sleep pauses every worker and cuts off reports. Ask the user first; with their OK, run `caffeinate -i` in a pane you create.
8. Do T-000 yourself on the coordination branch: dependencies, scripts, test isolation, gate green. Record the base commit.

Model order is `haiku` < `sonnet` < `opus`. Herdr `--timeout` values are milliseconds. The task-specific values below (`E2E_DATABASE_NAME`, DB names, ports) come from the plan's "Worker environment" and orchestration sections.

## Wave Loop

Dispatch while there are fewer than **6 live worker panes**, or the plan's lower cap. Implementers, reviewers and fix workers all count; a `caffeinate` pane does not.
- A task starts as soon as its own dependencies are `verified` and a pane is free. It does not wait for the rest of its wave.
- When a pane frees up, use it in this order: pending reviews and re-reviews first (they unblock merges), then fix rounds, then new implementers in plan order.
- The cap changes only by a new explicit user instruction, recorded as a D-number.

1. **Prepare each task.** You can do this while the cap is full, so the task launches as soon as a pane frees up:
   - create the worktree and branch from the coordination branch;
   - generate the worktree `.env` as a copy of the coordination `.env` with its own DB and port (never edit the coordination `.env` itself);
   - create its dev and test databases;
   - run `pnpm install --frozen-lockfile`;
   - write `<report-dir>/<task>.vault.md`: reread the notes through the MCP and quote the lines the task needs.
2. **Build the package:** `bash <skill-dir>/scripts/make-package.sh --plan … --task T-0NN …`. Recurring finding classes from earlier reviews go in `--notes` (see Learning Across Tasks).
3. **Create or reuse a pane.**
   - **Layout:** check the tab width with `herdr pane layout --pane "$HERDR_PANE_ID"`.
     - At least 180 characters wide: your pane plus two worker columns of up to 3 panes each.
     - Narrower: one worker column of up to 4 panes, and the cap drops to 4 (record why).
   - **Worker 1:** `herdr pane split --pane "$HERDR_PANE_ID" --direction right --cwd <wt> --no-focus` creates column A.
   - **Worker 2** (two-column layout): split column A's first pane `--direction right`, creating column B.
   - **Later workers:** first reuse a pane freed by `/exit` (`cd <wt>` there); otherwise split `--direction down` in whichever column has fewer panes.
   - Pass the worker's variables at split time: `--env E2E_DATABASE_NAME=<db>_test`. Read the id from `.result.pane.pane_id`.
   - In a reused pane, whether for an implementer or a reviewer, run `herdr pane run <pane> "cd <wt> && export E2E_DATABASE_NAME=<db>_test"`.
4. **Launch:**
   ```bash
   herdr agent start t0NN --kind claude --pane <pane> --timeout 120000 -- --model <plan model> --permission-mode <approved mode> --add-dir <report-dir> -n "T-0NN <label>"
   ```
5. **Verify the effective model**, for implementers and reviewers alike: `herdr agent read t0NN --source visible` shows it in the status line. Record "Opus 5.5 / Sonnet 5.5 …", or "effective model not verified".
6. **Prompt once.** Run it as a background command so you stay free while it works; your harness notifies you when the command returns:
   ```bash
   herdr agent prompt t0NN "Read <report-dir>/T-0NN.package.md and execute it exactly. Write your report to <report-dir>/T-0NN.md and end with STATUS and REPORT lines." --wait --timeout 3600000
   ```
7. **Update the scratchpad:** pane, model, worktree, `dispatched`.

While workers run, keep working on review packages, merges and reports. When idle, wait in bounded stretches and reconcile `herdr agent list` with the scratchpad.

## Accepting a Task

Accept a task only when every check below passes, in order:

1. The worker is `idle` or `done` (`blocked` and `unknown` are not settled), and the **report file** says PASS. Chat text does not count; read the file before writing `implemented`.
2. `git -C <wt> diff --stat $(git -C <wt> merge-base <coordination-branch> HEAD)...HEAD` touches only the task's allowed files. Use the merge-base, because the coordination branch may have been merged into the task branch.
3. You re-ran the task's Verify commands in the worktree, and they are green.
4. **Independent review** (`in review`). Pick the pane:
   - **below the cap:** keep the implementer alive and start the reviewer in a new pane. A fix round can then go to the same session, which keeps its context;
   - **at the cap:** exit the implementer (`/exit`) and confirm with `herdr pane read <pane> --source visible` that the shell prompt is back. If an exit dialog is still showing, close the pane and split a new one.

   Launch the reviewer as agent `t0NN-r<N>` with the same flags and `-n "T-0NN review"`.
   - **Model:** ≥ the implementer's, and `opus` for security, payments or transactions. A review by a weaker model does not count: rerun it.
   - **Prompt:** "Read <the path printed by `bash <skill-dir>/scripts/make-review-package.sh … --attempt N`> and execute it exactly."
   - Each attempt has its own files (`<task>.review.md`, `<task>.review-a2.md`, …), so earlier reviews are kept.
5. Verdict `APPROVED` → merge. `CHANGES_REQUIRED` → fix round:
   - write `<task>.fix-a<N>.md` from `fix-round-template.md` and give it to the implementer session if it is alive, otherwise to a fresh worker `t0NN-f<N>` in the same worktree;
   - send a scoped re-review with the next review attempt number;
   - escalate if a second fix round still fails on the same finding: a fresh worker one tier up, passing on every previous report and review. If the implementer was already `opus`, debug the finding yourself with systematic-debugging, then either write a tighter fix brief or split the task.
   - Fix rounds, retries and escalations always go through a fix file, which keeps the original package and appends to the same report. Use `make-package.sh --attempt N` only for a full restart from scratch; it writes `-aN` files and overwrites nothing.
6. **Merge:** `git merge --no-ff <task-branch>` into the coordination branch.
   - Conflicts are expected only in shared registration files that the plan lists in more than one task (module imports, routes). Resolve them by keeping both sides.
   - Run the **full gate**. Only a green gate makes the task `verified`. Then close that task's panes.

## When a Worker Stops or Breaks

| Situation | Action |
|---|---|
| BLOCKED by something you own (T-000 dependencies, a contract, a stale test) | Fix it on the coordination branch and run the gate. Merge the coordination branch into the task branch, re-running install if the lockfile changed. Re-prompt **the same session** with a short message: fix commit, what changed, continue. A narrow out-of-scope edit may be authorized in writing in that prompt; record it as a D-number. |
| A worker asks a question in chat instead of reporting BLOCKED | Same rules as BLOCKED: answer routine in-scope questions with a new prompt. Dependencies and contracts are yours, so handle them as in the row above. Scope-changing questions go to the user. |
| Report says FAIL | Read it and diagnose. Retry once with a prompt that names the failure mode; never resend the same prompt. If it fails again, escalate or split as in Accepting step 5. |
| `--wait` timed out while still `working` | Inspect `herdr agent read` and `git log`. If it is progressing, wait again with `herdr agent wait t0NN --timeout 3600000` in the background. If nothing changed in 20 minutes, send `esc` with `send-keys` and ask for a status report. |
| `idle` but no report (sleep, cut-off output) | Check `git log` in the worktree. Ask the same session to write only the report, re-running Verify for observed results, without redoing the work. Never resend the whole prompt. |
| `blocked` on a tool-permission prompt | Do not answer it. Read the pane, then tell the user, or change the dispatch deliberately. |
| An optional UI dialog that grants nothing (e.g. "Teach auto mode about your environment?") | Confirm what it is with `herdr agent read`, then pick "Not now" with `send-keys` (`down`, `enter`). It does not change permissions or config. |
| Vault MCP fails mid-run | Tell the user, record it, and try one reconnect. Tasks whose packages need new vault excerpts wait. Excerpts already quoted this run may be reused only if the notes were not edited since. Queue vault writes in the scratchpad. Never read the vault from disk. |
| Integration gate red after a merge | Stop further merges and find the cause with systematic-debugging. Never edit tests just to make them green. |
| ↳ cause is shared and yours (often a test helper that does not know a new table) | Fix it in an orchestrator commit on the coordination branch, then run the gate again. |
| ↳ cause is the merged task's own code | Send a fix round on its task branch and merge again. If other merges are waiting, `git revert -m 1 <merge>` first; never `reset --hard`. |
| A worker changed files outside its scope | Do not accept the task, and stop its dependents. Send a fix round asking the worker to revert that change. If the change is actually required (a plan defect), authorize it as a D-number and have the reviewer judge it. |

## When the User Overrides the Process

| User says | Action |
|---|---|
| "Merge without review" | Allowed: the user sets scope. Still read the report, check scope, re-run Verify and run the gate. Record the waiver as a D-number; status `verified (review waived)`, never `completed`. Queue the reviews as remaining work, and say which waived tasks touch security or payments. |
| "Merge" or "mergeá" | Means the coordination branch. `main`, a push or a PR needs the user to name it explicitly. |
| "Stop everything", "pará todo" | Stop dispatching, merging and prompting. Send `esc` to working agents; this keeps their sessions. Do not close panes or touch worktrees. Write the scratchpad, give a status, then wait. |
| "Use N workers" | The new cap applies from now on. Record it as a D-number and re-check the layout width. |
| "Delete the worktrees" or other cleanup | Run `git worktree list`. Remove only clean worktrees whose branch is merged, with `git worktree remove <path>`: no `--force`, then `git worktree prune`. Report dirty or unmerged ones and ask. Delete branches (`git branch -d`, never `-D`) and drop databases only when the user asks for them too. |

## Learning Across Tasks

When a review finds a class of defect, check whether it can recur, and add it to the `--notes` of every later package and review package. Examples: unbounded input reaching the database as a 500, pagination counting joined rows, stale cache after a failed mutation. Also check already-integrated tasks for the same pattern yourself. Hits become a new fix task (the next ID; see "New task IDs" in Closing the Run) that goes through a worker and review like any other task.

DAG deviations are allowed when they are provably safe; for example, a read-only review in parallel with a test-only task. Record each one.

## Closing the Run

1. Run the **cross-cutting review** (read-only, opus) on the integrated branch.
   - Package it with `make-package.sh --role review`. It gets no per-task review and no merge; its findings report is the result.
   - Turn its Critical and Important findings into fix tasks (the next IDs) and record the deferred Minor ones as debt.
   - **New task IDs** (fix tasks, split tasks, hits from Learning Across Tasks): before packaging, append a full `### Task T-0NN: <title>` section with its header line to the plan under `## Tasks`, replacing its reserved slot. Record it as a D-number. Packages always come from the plan, never hand-written.
2. Run the final gate, including the browser smoke test, and record the commit.
3. If the user asked for a local run:
   - pass secrets as process environment from a 0600 file in the session scratchpad;
   - never edit `.env` without permission;
   - give credentials only in chat.
4. **Vault sync:**
   - use the vault MCP; use `updating-typed-knowledge-vaults` for typed vaults;
   - move notes from proposed to shipped, with sources;
   - add an ADR for each decision and a failure note for each lesson;
   - update `last-sync`, run the validator, and queue anything that fails in the scratchpad.
5. Close only the panes this run created. Keep worktrees, branches and databases until the user confirms cleanup.
6. Update the scratchpad and, if the project keeps one, the daily log (one line per milestone during the run, not only at the end). Give the user the result, the checks run, limitations, remaining work and live resources. Push, PR or merge to `main` only with explicit authorization.

## Status and Resume

For "status", "qué falta" or "continuá":
1. Start from the scratchpad.
2. Verify it against `git worktree list`, `git log`, `herdr agent list` and the report dir. A recorded status does not prove a process is alive.
3. Answer with progress, remaining work, blockers and the next action.

## Quick Reference

| Need | Command |
|---|---|
| Worker package | `bash <skill-dir>/scripts/make-package.sh --plan P --task T-0NN --model M --why W --run-id R --reports D --worktree WT --branch B --base SHA --coord ROOT --coord-branch CB [--vault-excerpts F] [--notes F] [--env "…"] [--role review] [--attempt N]` |
| Review package | `bash <skill-dir>/scripts/make-review-package.sh --task T-0NN --model M --run-id R --reports D --worktree WT --branch B --base $(git -C WT merge-base CB HEAD) [--notes F] [--attempt N]` |
| Fix round | `fix-round-template.md` → `<report-dir>/<task>.fix-a<N>.md` |
| Live agents | `herdr agent list` · `herdr agent get <name>` · `herdr agent read <name> --source recent-unwrapped --lines 120` |
| Scope check | `git -C <wt> diff --stat $(git -C <wt> merge-base <coordination-branch> HEAD)...HEAD` |

## Red Flags

These thoughts mean stop:

| Thought | Reality |
|---|---|
| "The worker said PASS, merge it" | Read the report, check the scope, re-run Verify, review, then merge |
| "Same model for every worker is simpler" | The plan names a model per task; record the effective one |
| "Resend the prompt, it probably didn't arrive" | Inspect state and output first; duplicate prompts duplicate work |
| "The gate failure isn't from this task, merge the next one" | A red gate stops the merges until it is understood and fixed |
| "I'll answer the worker's permission prompt to save time" | Never answer another agent's permission request |
| "Quick fix it in the worker's worktree myself" | Fix rounds go through a worker; you fix only what you own, on the coordination branch |
| "Cleanup worktrees and branches now" | Only after the user confirms |
