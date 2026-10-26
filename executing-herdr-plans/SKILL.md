---
name: executing-herdr-plans
description: Use when executing an approved plan (code, audit, research, documents) by orchestrating independent Claude Code workers in Herdr panes, or when resuming, checking status of, closing such a run, or taking it over as a relief orchestrator
---

# Executing Herdr Plans

## Overview

One orchestrator session runs a plan written with **writing-herdr-plans**. It runs the plan wave by wave: each task goes to a fresh Claude Code worker in its own Herdr pane (a git worktree for code tasks), is checked by an independent reviewer and is integrated by the orchestrator behind a gate (a full gate after every merge, for code tasks).

**Core principle:** a worker's report is a claim, not evidence. A task is `completed` only after it has been implemented, reviewed, integrated and verified, and the orchestrator has checked each step itself.

**REQUIRED BACKGROUND:** the `herdr` and `herdr-agent-orchestration` skills (CLI and lifecycle states), superpowers:verification-before-completion, superpowers:receiving-code-review. Use superpowers:systematic-debugging for any red gate.

`<skill-dir>` below is this skill's base directory (shown when the skill loads, e.g. `~/.claude/skills/executing-herdr-plans`). Always call the scripts by that absolute path, because you run from COORDINATION_ROOT.

**Herdr agent names** must be unique among live agents:
- implementer: `t0NN`;
- reviewer: `t0NN-r<N>` (N = review attempt);
- fresh fix worker: `t0NN-f<N>` (N = fix attempt);
- ClickUp sync worker: `clickup`;
- orchestrators: `orch-1` (you, renamed in the preflight), then `orch-2`, `orch-3`, … for each relief (see Handing Off).

The `-n` label is only Claude's display name.

## Roles

- **Orchestrator (you):**
  - owns T-000, worktrees, databases, launches, merges into the coordination branch, gates, the deliverable (findings and document tasks) and all Git;
  - is the only writer of `SCRATCHPAD.md` and the vault;
  - keeps its own context under **70%** and hands the run to a relief orchestrator when it gets there (Context check, Handing Off). The run never relies on context compaction;
  - records every user instruction that changes the run as a D-number **when it is given**: after a hand-off, only the scratchpad speaks.
- **Worker:** executes one package, writes one report and never orchestrates.
  - Workers may use internal subagents for analysis; those never replace Herdr workers.
- **ClickUp sync worker** (only if the plan has a ClickUp block): the only writer to the board, through the ClickUp MCP. It creates and edits tasks from the events you send it; it has no code access and never receives a task package. Task workers and reviewers never hear of ClickUp.
- **Decide routine technical questions yourself** and record them as D-numbers. Ask the user only for:
  - product decisions that change scope;
  - destructive or security-sensitive actions;
  - push, PR or merges into shared branches.

## What changes per kind

Each task has a `Kind` (`code` when the header has none). The core below works for every kind. A kind's own steps are in its file, which you read only when the plan has that kind. Its headings tell where each step goes: Stack confirmation or Scope and access confirmation (Preflight 4), Preparing (Wave Loop 1), Accepting (Accepting 2–3), Integrating (Accepting 6), Failures, Closing and Red flags.

| Kind | What the worker delivers | Read when the plan has it |
|---|---|---|
| `code` | Code on its own branch and worktree, with a green Verify | `kinds/code.md` |
| `findings` | A findings report with evidence, from read-only access | `kinds/findings.md` |
| `document` | A document part with sources, written under the report dir | `kinds/document.md` |

## Preflight (once per run)

1. `test "$HERDR_ENV" = 1`. If it fails, record the blocker and ask the user to start the orchestrator inside a Herdr pane.
2. Check versions and syntax:
   - `herdr --help`, `herdr agent`, `herdr integration status` (expect `claude: current`);
   - `claude --help` for `--model`, `--permission-mode`, `--add-dir`, `-n`;
   - your own context reading: `herdr pane read "$HERDR_PANE_ID" --source visible | grep -o 'ctx:[0-9]*%' | tail -1` must print a value (e.g. `ctx:12%`). It comes from the user's Claude Code status line (`context_window.used_percentage`). If it prints nothing, stop and ask the user to add it to their status line: the hand-off rule depends on it. Record `Context monitoring: ok` and the value in the scratchpad;
   - name yourself: `herdr agent rename "$HERDR_PANE_ID" orch-1` (a relief keeps the name it was started with), and record your own model alias (the one the user started you with; the status line shows its display name) as a D-number: a relief is started with it.
3. Read the scratchpad (`scratchpad-template.md` if missing), the plan and its summary. Confirm the vault MCP is connected before reading the vault notes the tasks name.
   - If the MCP fails: tell the user, record the blocker, and continue only the tasks that do not depend on vault content. Queue the vault updates in the scratchpad.
   - Never fall back to reading vault files from disk.
4. **Up-front confirmation** (the only up-front stop of the run; read-only, install nothing). Build the confirmation for the kinds in the plan, show it to the user, and wait for their answer before step 5.
   - Code tasks: `kinds/code.md § Stack confirmation`. Findings and document tasks: `kinds/<kind>.md § Scope and access confirmation`. A mixed plan shows both tables in one message.
   - Batch into the same message the other questions this preflight needs: permission mode (step 7), keeping the machine awake (step 8) and a ClickUp board decision still `to confirm` (step 9).
   - Urgency never skips it, and you never approve a row for the user. On resume, the resume rule in the kind file's confirmation section applies.
5. Create the report dir: `mkdir -p -m 700 ~/.cache/herdr-reports/<run-id>`. Packages, reports, reviews, fix files and vault excerpts (`<task>.vault.md`) all live there.
6. Check that the plan has the writing-herdr-plans headings: build the first task's package (T-001) with `make-package.sh`, whatever its kind. The script fails and names any missing section.
7. **Permission mode.** Workers need a write-capable mode.
   - Launching with `--permission-mode auto` may be denied by the permission classifier. If so, ask the user once to authorize it and record the answer as a D-number.
   - If the user refuses, ask which write-capable mode they approve (e.g. `acceptEdits`, approving commands in each pane). Never switch to bypass flags.
   - Non-code workers (findings, document) do not use a write-capable mode: they launch with `--permission-mode dontAsk --allowedTools "<read tools, read-only commands the plan names, Write/Edit only under <report-dir>>"`. Verify both flags against `claude --help` before the first launch, and have the user approve the allowlist in step 4.
8. **Keep the machine awake.** Sleep pauses every worker and cuts off reports. Ask the user first; with their OK, run `caffeinate -i` in a pane you create.
9. **ClickUp sync** (skip if the plan says `**ClickUp:** none`). Verify first, then start the worker:
   - the plan's board decision is `approved`. If it is still `to confirm`, ask the user now: creating tasks is outward-facing;
   - `claude mcp list` shows ClickUp connected. If not, tell the user, queue the events in the scratchpad and run without the worker;
   - start the worker with the plan's launch block: `herdr agent start clickup --kind claude --pane <pane> --timeout 120000 -- --model <plan model> <verified tool allowance> -n "ClickUp sync"`, in `<report-dir>` and without `--add-dir` of any worktree. Verify its effective model like any worker;
   - send the first prompt from the plan: list id, status mapping, limits, and the map file `<report-dir>/clickup-map.json`;
   - send `plan created`. The worker creates one task per plan task and reports the map. Read the board back yourself for a sample of tasks (`clickup_get_task`) before writing `ClickUp sync: started` in the scratchpad.

   It is not a task worker, but it does count toward the cap of live panes.
10. Do T-000 yourself as the kind files describe; record the base commit and, for findings and document tasks, the sources baseline. For code, T-000 is on the coordination branch: dependencies, scripts, test isolation, gate green.

Model order is `haiku` < `sonnet` < `opus`. Herdr `--timeout` values are milliseconds.

## Wave Loop

Dispatch while there are fewer than **6 live worker panes**, or the plan's lower cap. Implementers, reviewers, fix workers and the `clickup` worker all count; a `caffeinate` pane does not.
- A task starts as soon as its own dependencies are `verified` and a pane is free. It does not wait for the rest of its wave.
- When a pane frees up, use it in this order: pending reviews and re-reviews first (they unblock merges), then fix rounds, then new implementers in plan order.
- The cap changes only by a new explicit user instruction, recorded as a D-number.

1. **Prepare each task as its kind file says** (`kinds/<kind>.md`, Preparing). You can do this while the cap is full, so the task launches as soon as a pane frees up.
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
   - Non-code tasks (findings, document): `<wt>` is the coordination root, pass no `--env`, and launch with the non-code mode of Preflight step 7.
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

### Context check

Before every dispatch, before every merge, and each time you reconcile `herdr agent list`, read your own context:

```bash
herdr pane read "$HERDR_PANE_ID" --source visible | grep -o 'ctx:[0-9]*%' | tail -1
```

Write the value and the time in the scratchpad header. The reading lags one turn; that is fine. At **70% or more**, finish only the step in progress (the merge, the gate, or the package you are writing; never the wave) and go to Handing Off. The threshold changes only by an explicit user instruction, recorded as a D-number.

### ClickUp events

Right after you write a state in the scratchpad, send the matching event to `clickup` as one background prompt, batching the events that happened together:

```bash
herdr agent prompt clickup "T-004 → in progress | pane <id>, model sonnet" --wait --timeout 600000
```

| Scratchpad moment | Event |
|---|---|
| Dispatched | `in progress` |
| Report read, review starts | `in review` |
| Merged | `integrated` |
| Full gate green | `verified` |
| Blocked on something you cannot fix at once | `blocked`, with the reason |
| Plan edited (new task IDs, a fix or split task, changed criteria or dependencies) | `plan revised`, with the changed fields |

- For non-code tasks, `integrated` means the part was copied into `deliverables/<run-id>/parts/`, and `verified` means the plan's gate is green over the parts.
- Each line is `T-0NN → <state> | <evidence: commit, report path or gate result>`. Never send secrets or PII.
- Send an event only after you have verified the state. A worker's claim is not an event.
- Never wait on ClickUp: no dispatch, merge or gate depends on its answer.
- Read the worker's reply (`STATUS` and the map). If it reports a failure, queue the events in the scratchpad and apply "ClickUp MCP fails" below.

## Accepting a Task

Accept a task only when every check below passes, in order:

1. The worker is `idle` or `done` (`blocked` and `unknown` are not settled), and the **report file** says PASS. Chat text does not count; read the file before writing `implemented`.
2. **Scope and verification:** the kind file's Accepting section (`kinds/<kind>.md`): what the task may touch and how you check it.
3. The same section says how you re-run the task's Verify commands, and they are green.
4. **Independent review** (`in review`). Pick the pane:
   - **below the cap:** keep the implementer alive and start the reviewer in a new pane. A fix round can then go to the same session, which keeps its context;
   - **at the cap:** exit the implementer (`/exit`) and confirm with `herdr pane read <pane> --source visible` that the shell prompt is back. If an exit dialog is still showing, close the pane and split a new one.

   Launch the reviewer as agent `t0NN-r<N>` with the same flags and `-n "T-0NN review"`.
   - **Model:** ≥ the implementer's, and `opus` for security, payments or transactions. A review by a weaker model does not count: rerun it.
   - **Prompt:** "Read <the path printed by `bash <skill-dir>/scripts/make-review-package.sh … --attempt N`> and execute it exactly."
   - Each attempt has its own files (`<task>.review.md`, `<task>.review-a2.md`, …), so earlier reviews are kept.
5. Verdict `APPROVED` → integrate (step 6). `CHANGES_REQUIRED` → fix round (for findings and document tasks, `CHANGES_REQUIRED` follows the kind file's rules):
   - write `<task>.fix-a<N>.md` from `fix-round-template.md` and give it to the implementer session if it is alive, otherwise to a fresh worker `t0NN-f<N>` in the same worktree;
   - send a scoped re-review with the next review attempt number;
   - escalate if a second fix round still fails on the same finding: a fresh worker one tier up, passing on every previous report and review. If the implementer was already `opus`, debug the finding yourself with systematic-debugging, then either write a tighter fix brief or split the task.
   - Fix rounds, retries and escalations always go through a fix file, which keeps the original package and appends to the same report. Use `make-package.sh --attempt N` only for a full restart from scratch; it writes `-aN` files and overwrites nothing.
6. **Integration:** the kind file's Integrating section (`kinds/<kind>.md`). A findings task is integrated by copying its report, with the reviewer's verdicts applied, to `deliverables/<run-id>/parts/<TASK>.md`; the details are in `kinds/findings.md`.

## When a Worker Stops or Breaks

| Situation | Action |
|---|---|
| BLOCKED by something you own, or the integration gate red after a merge (code tasks) | `kinds/code.md § Failures (code)`. Failures of findings and document tasks are in their kind files, under Failures. |
| A worker asks a question in chat instead of reporting BLOCKED | Same rules as BLOCKED: answer routine in-scope questions with a new prompt. Dependencies and contracts are yours, so handle them as in the row above. Scope-changing questions go to the user. |
| Report says FAIL | Read it and diagnose. Retry once with a prompt that names the failure mode; never resend the same prompt. If it fails again, escalate or split as in Accepting step 5. |
| `--wait` timed out while still `working` | Inspect `herdr agent read` and `git log`. If it is progressing, wait again with `herdr agent wait t0NN --timeout 3600000` in the background. If nothing changed in 20 minutes, send `esc` with `send-keys` and ask for a status report. |
| `idle` but no report (sleep, cut-off output) | Check `git log` in the worktree. Ask the same session to write only the report, re-running Verify for observed results, without redoing the work. Never resend the whole prompt. |
| `blocked` on a tool-permission prompt | Do not answer it. Read the pane, then tell the user, or change the dispatch deliberately. |
| An optional UI dialog that grants nothing (e.g. "Teach auto mode about your environment?") | Confirm what it is with `herdr agent read`, then pick "Not now" with `send-keys` (`down`, `enter`). It does not change permissions or config. |
| Vault MCP fails mid-run | Tell the user, record it, and try one reconnect. Tasks whose packages need new vault excerpts wait. Excerpts already quoted this run may be reused only if the notes were not edited since. Queue vault writes in the scratchpad. Never read the vault from disk. |
| ClickUp MCP fails mid-run, or the `clickup` worker errors or stalls | Tell the user, record it, and try one reconnect or restart of the worker with the same prompt and map file. Meanwhile queue the events in the scratchpad (task, state, evidence) and keep going. After recovery, send the queue as one batch. Never answer its permission prompts, and never write to ClickUp yourself or from a task worker. |
| ClickUp board differs from the scratchpad (a task missing, duplicated or in another status) | The scratchpad wins. Send a `plan revised` or state event that corrects it, and read the board back. |
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

For plans with findings or document tasks the order is: consolidation task, deliverable (step 2b), cross-cutting review (step 1), reserved fix tasks, final gate.

1. Run the **cross-cutting review** (read-only, opus) on the integrated branch or the deliverable.
   - Package it with `make-package.sh --role review`. It gets no per-task review and no merge; its findings report is the result.
   - `--role review` is for code. In a plan without code, the cross-cutting review is a `findings` task over the deliverable, packaged like any findings task. In a mixed plan it covers the integrated branch (`--role review`) and the deliverable.
   - Turn its Critical and Important findings into fix tasks (the next IDs) and record the deferred Minor ones as debt.
   - **New task IDs** (fix tasks, split tasks, hits from Learning Across Tasks): before packaging, append a full `### Task T-0NN: <title>` section with its header line to the plan under `## Tasks`, replacing its reserved slot. Record it as a D-number. Packages always come from the plan, never hand-written.
2. Run the final gate, including the browser smoke test, and record the commit.
   - UI plans: `kinds/code.md § Closing (code)`.
2b. **Deliverable** (plans with findings or document tasks). Once the consolidation task is accepted and integrated like any document task, place its part `deliverables/<run-id>/parts/<consolidation TASK>.md` as the deliverable `<name>.md` under `deliverables/<run-id>/`, and its `.html` too when the format is html (the consolidation worker writes it). Commit it on the coordination branch as the deliverable decision says (not at all if the decision is outside the repo). For html, run `grep -Eic '<script|<link[^>]*href="https?:|src="https?:' <file>`: it must print `0`. After any later fix task that changes a part or the consolidation, re-run the consolidation as needed, place `<name>.md`/`.html` again, re-run the html check when html, and commit again as decided. Give the user the deliverable's absolute path only once, in step 7, when no fix task is pending.
3. If the user asked for a local run:
   - pass secrets as process environment from a 0600 file in the session scratchpad;
   - never edit `.env` without permission;
   - give credentials only in chat.
4. **Vault sync:**
   - use the vault MCP; use `updating-typed-knowledge-vaults` for typed vaults;
   - move notes from proposed to shipped, with sources;
   - add an ADR for each decision and a failure note for each lesson;
   - update `last-sync`, run the validator, and queue anything that fails in the scratchpad.
5. **ClickUp final sync** (if the worker ran): send the last events, including the `verified` states and the cross-cutting review's fix tasks and deferred debt. Read the board back (`clickup_filter_tasks` on the list) and compare it with the scratchpad's tasks table. Record the result in the scratchpad's ClickUp section; if they differ, say which tasks. Then `/exit` the worker.
6. Close only the panes this run created, except your own. Keep worktrees, branches and databases until the user confirms cleanup.
7. Update the scratchpad and, if the project keeps one, the daily log (one line per milestone during the run, not only at the end). Give the user the result, the checks run, limitations, remaining work and live resources. Push, PR or merge to `main` only with explicit authorization.

## Handing Off to a Relief Orchestrator

At 70% context you hand the run to a fresh session, `orch-<N>`, that resumes from the scratchpad. Nothing in your chat survives: the relief has the scratchpad, the plan, the D-numbers and the report dir, and nothing else. Workers do not notice; their reports are files. You run from COORDINATION_ROOT, so `$PWD` below is that directory.

### As the outgoing orchestrator

1. **Safe point.** No merge or gate running, no package half-written, no user instruction unrecorded. Send the ClickUp events you owe and read their replies; what failed goes to the queue in the entry. Your background `--wait` commands die with your session; the relief re-arms them.
2. **Start the relief** below your own pane, so it takes your column when yours closes. Its pane does not count toward the worker cap.
   ```bash
   split=$(herdr pane split --pane "$HERDR_PANE_ID" --direction down --cwd "$PWD" --no-focus)
   pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')
   herdr agent start orch-<N> --kind claude --pane "$pane" --timeout 120000 -- --model <your model alias, from its D-number> --permission-mode <approved mode> --add-dir <report-dir> -n "Orchestrator <N>"
   ```
   Verify its effective model as for any worker. Never start it with `--resume` or `--continue`: that loads the context you are shedding.
3. **Write the hand-off entry** from `handoff-template.md` into the scratchpad, from a fresh `herdr agent list` and `herdr pane layout`, never from memory: relief pane and effective model; live agents with pane, state, worktree and the report each will write; column layout; queued ClickUp events; the exact next action. Then write the relief prompt from the same template to `<report-dir>/handoff-orch-<N>.md`.
4. **Prompt it once**, no `--wait`: `herdr agent prompt orch-<N> "Read <report-dir>/handoff-orch-<N>.md and execute it exactly."`
5. **Wait for its confirmation**, bounded and in the background: `timeout 600 bash -c 'until grep -q "Resumed by orch-<N>" SCRATCHPAD.md; do sleep 15; done'`. Your turn ends there and Herdr shows you `idle`; that is expected. Until that line exists, the run is still yours: if a worker reports meanwhile, re-read the scratchpad and add one line under the entry (`t005 reported <report path> at <time>`) and nothing else; no accept, dispatch or merge. If the loop expires, read `herdr agent read orch-<N>`: a permission prompt goes to the user, never answered by you; still `working` → wait once more; dead or stuck → record it, `herdr pane close` its pane, and start `orch-<N+1>` from step 2.
6. **Leave.** When the loop returns with the line present, say one line to the user (the run now belongs to `orch-<N>`) and stop. Write nothing more in the scratchpad and run nothing more: no dispatch, merge or prompt. The relief closes your pane and announces itself; you cannot run `/exit` on yourself. If the relief closed your pane before the loop returned, nothing is lost.

### As the relief

1. Preflight as a resume: `HERDR_ENV`, versions, your own context reading, `claude mcp list` for the vault and ClickUp MCPs. Skip the stack confirmation under the resume rule of preflight step 4, and skip T-000. Reuse the recorded D-numbers for model, permission mode and cap; do not create new ones.
2. Read the whole scratchpad (D-numbers, tasks table, ClickUp section), the plan and its summary; the last hand-off entry is your starting point. Append `Resumed by orch-<N> at <time>` to Recent activity. From that line, you are the only writer; only then update the header with your context reading and `Context monitoring: ok`.
3. Reconcile `herdr agent list`, `git worktree list` and the report dir with the entry. A difference (a report already present, an agent gone) is a line in Recent activity now and a step of the wave loop later, not a reason to act here. Re-arm one background `herdr agent wait <name> --timeout 3600000` per agent whose row says `working`. Send the queued ClickUp events.
4. `herdr agent wait <outgoing name> --timeout 600000` until it is idle, then `herdr pane close <its pane>`. Closing the previous orchestrator's pane is the one exception to "close only panes you created"; never close it while it is `working` (wait again). Then `herdr agent focus orch-<N>` and tell the user in one line that you own the run in this pane.
5. Continue the wave loop from "Next action". Hand off to `orch-<N+1>` the same way at 70%.

## Status and Resume

For "status", "qué falta" or "continuá":
1. Start from the scratchpad. If its last hand-off entry has no matching `Resumed by` line, the relief never took over: the run is yours, continue from the entry.
2. Verify it against `git worktree list`, `git log`, `herdr agent list` and the report dir. A recorded status does not prove a process is alive. If the `clickup` worker is gone, restart it with its first prompt and `clickup-map.json`, then send the queued events plus the current state of every task.
3. Answer with progress, remaining work, blockers and the next action.

## Quick Reference

| Need | Command |
|---|---|
| Worker package | `bash <skill-dir>/scripts/make-package.sh --plan P --task T-0NN --model M --why W --run-id R --reports D --worktree WT --branch B --base SHA --coord ROOT --coord-branch CB [--vault-excerpts F] [--notes F] [--env "…"] [--role review] [--attempt N] [--kind K]` |
| Review package | `bash <skill-dir>/scripts/make-review-package.sh --task T-0NN --model M --run-id R --reports D --worktree WT --branch B --base $(git -C WT merge-base CB HEAD) [--notes F] [--attempt N] [--kind K] [--integrated DIR]` |
| Fix round | `fix-round-template.md` → `<report-dir>/<task>.fix-a<N>.md` |
| Own context | `herdr pane read "$HERDR_PANE_ID" --source visible \| grep -o 'ctx:[0-9]*%' \| tail -1` |
| Hand-off | `handoff-template.md` → scratchpad entry + `<report-dir>/handoff-orch-<N>.md` · `herdr agent start orch-<N> …` · confirm with `Resumed by orch-<N>` |
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
| "I'll update ClickUp myself, it's one call" | Only the `clickup` worker writes to the board; you send events |
| "ClickUp says Done, so it's done" | The scratchpad is the source of truth; ClickUp mirrors verified states |
| "Wait for ClickUp before dispatching" | ClickUp never gates a wave; queue the events and continue |
| "I'm at 72% but this wave is almost done" | The safe point is the step in progress, not the wave. Hand off now |
| "The relief can ask me for the details" | It cannot. What is not in the scratchpad, the plan or the report dir does not exist |
| "Start the relief with `--resume` so it knows everything" | That loads the context you are shedding. Fresh session, from the scratchpad |
| "I'll `/exit` myself after starting the relief" | You cannot run slash commands on yourself; the relief closes your pane |

Each kind file has its own Red flags section (`kinds/code.md § Red flags (code)`).
