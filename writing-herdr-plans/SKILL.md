---
name: writing-herdr-plans
description: Use when writing an implementation plan from an approved spec that will be executed by an orchestrator Claude session delegating tasks to independent Claude Code workers in Herdr panes, each in its own git worktree
---

# Writing Herdr Plans

## Overview

A plan for Herdr orchestration is a `superpowers:writing-plans` plan plus everything an orchestrator needs to run it with independent workers: fixed contracts, a wave DAG with a model per task, a reproducible worker environment, and sections with fixed headings so each worker's package can be cut out of the plan mechanically.

**REQUIRED SUB-SKILL:** Use superpowers:writing-plans and follow it entirely (header, Global Constraints, Review Focus, file structure, TDD task steps, no placeholders, self-review). This skill only adds to it and overrides it where stated.

**Core principle:** a worker sees only its package, never the conversation, the vault or other tasks. Anything a worker needs must be in a plan section that gets copied into its package.

**Announce at start:** "I'm using the writing-herdr-plans skill to create the orchestrated implementation plan."

## When to Use

- The user asks for a plan that will be executed "with herdr", by parallel workers, or by an orchestrator.
- The project's instructions define an orchestrator/worker split, a scratchpad or a delegation contract.

Not for: plans executed in one session (use superpowers:writing-plans alone), or a request that only needs analysis.

## Before Writing

1. **Roles.** You are the orchestrator: the only writer of the plan, the scratchpad and the project's knowledge vault.
2. **State.** Read `SCRATCHPAD.md` at the coordination checkout root (`COORDINATION_ROOT`, an absolute path that stays fixed for the run). If it is missing, create it from `scratchpad-template.md` in the sibling skill **executing-herdr-plans** (REQUIRED: both skills are installed together).
3. **Vault check, before any planning.** Confirm that the vault MCP (e.g. `obsidian-mcp`) is connected and its tools are listed. Then list the vault and look for this project's notes: search the project name, terms from the spec, and links already in the scratchpad. Record the outcome in the scratchpad:

   | Outcome | Action |
   |---|---|
   | Project notes found | Read the relevant ones: requirements, decisions, constraints, failures, architecture. Note the paths, because each task will name the notes its worker needs. |
   | Several vaults or projects match | Ask the user which one before reading further or writing. |
   | MCP not connected or failing | Tell the user and record the blocker. Ask whether to fix the MCP first or plan without the vault. Never read or edit vault files from disk instead. |
   | MCP works, but this project has no notes | Tell the user and offer to create the vault first from the spec (`creating-typed-knowledge-vaults`), so business risks are mapped before the code. If they decline, plan with `**Vault:** none`. |
   | The only vault belongs to another project | Same as "no notes". Also ask whether this project should get its own vault or a section in that one. Notes from the other project are not this project's facts; cite one only as a labeled analogy. |

   - User urgency ("armá el plan ya") does not skip this check. It makes the question one line long.
   - While waiting for an answer, continue work that does not need the vault, such as tooling checks and listing open decisions.
   - During planning, the vault is only read. Write to it only to create it, if the user accepted; decisions reach the vault at the closing sync.
4. **ClickUp board check.** The plan includes a ClickUp sync worker that mirrors task progress to the project's board. Confirm that the ClickUp MCP is connected (`claude mcp list`) and its `clickup_*` tools are listed. Then find the project's board read-only (`clickup_search`, `clickup_get_workspace_hierarchy`, `clickup_get_list`): record the list id, its exact status names and any board link already in the scratchpad.

   | Outcome | Action |
   |---|---|
   | One matching board | Record it as a `to confirm` decision: list id, status mapping (below) and permission to create one ClickUp task per plan task. Creating tasks is outward-facing, so nothing is written to ClickUp during planning. |
   | Several candidates, or none | Ask the user which list to use, or whether to create one. Never create folders or lists on your own. |
   | MCP not connected or failing | Tell the user and record the blocker. Ask whether to fix it first or plan with `**ClickUp:** none`. |
   | The user declines ClickUp | Plan with `**ClickUp:** none` and omit the sync worker. |

   - The status mapping assigns each ClickUp status to a task state: `planned`, `in progress`, `in review`, `integrated`, `verified`, `blocked`. Use only status names the list actually has; if one is missing, record that and map to the closest one, never invent statuses.
   - ClickUp is a mirror. The scratchpad stays the source of truth, and ClickUp never gates a wave.
6. **Tooling, verified, not remembered.** Run `herdr --help`, `herdr agent`, `claude --help`, `herdr integration status`, and `herdr pane layout --pane "$HERDR_PANE_ID"` (your pane id and the terminal width). Record the exact launch flags you will put in the plan, including how the ClickUp sync worker is allowed to call the `clickup_*` tools (`--allowedTools` or the permission mode).
7. **Decisions.** List every decision the spec leaves open.
   - A decision **changes scope** if it changes what users can do or see, the data users enter or receive, cost, external services, or security exposure. Ask the user about those, e.g. time zones for bookings, stock rules, who can see what.
   - Everything else is routine: internal naming, library choice within the stack, file layout. Adopt it yourself with status `adopted by orchestrator`.
   - When the spec, the vault and the user disagree, record the discrepancy; the user's current instruction wins.
   - Global stack defaults (e.g. a company CLAUDE.md) yield to an approved spec that names a different choice. Record the discrepancy as a D-number.

## Plan Document Structure

Use these headings **exactly** and in this order. They are the contract with the sibling skill **executing-herdr-plans**: its `scripts/make-package.sh` finds sections by the exact heading text, optionally followed by ` (…)`. A suffix like `(orchestrator-only section)` is fine; `## Data contract v2` would not match `Data contract`.

| Section | Content | Copied into worker packages |
|---|---|---|
| Header (writing-plans) | Goal, Architecture, Tech Stack, Spec, vault location. The "For agentic workers" line adds: "executed with executing-herdr-plans; a worker implements only its own task". | no |
| `## Decisions recorded for this plan` | Table: `# · Decision · Source · Status` (`approved` / `adopted by orchestrator` / `to confirm`). IDs D1…Dn continue during execution. | yes |
| `## Global Constraints` | writing-plans rules + ownership rules (below). | yes |
| `## Review Focus` | writing-plans rules; each item names the owning task in brackets. | yes |
| `## Orchestration (orchestrator-only section)` | Waves/DAG, model table, launch recipe, ClickUp sync, acceptance, integration gate. Template: `orchestration-section-template.md`. | no |
| `## Worker environment` | What a worker's checkout looks like: branch naming, its own DB/ports/env var names, how to run commands, "no long-running servers". | yes |
| Contract sections (`## Data contract`, `## HTTP contract`, `## Frontend route map`, …) | Fixed shared contracts: schemas, endpoints with exact shapes, error codes, routes, shared copy. | only those a task lists |
| `## Tasks` | `### Task T-000: …` … one per task. | only its own task |
| `## Self-review` | writing-plans self-review plus the additions below. | no |

### Task header line

Directly under each `### Task T-0NN: <title>` heading:

```markdown
**Model:** opus · **Depends on:** T-001, T-002 integrated · **Parallel with:** T-005, T-006 · **Contracts:** Data contract, HTTP contract · **Vault:** concepts/Pedido, failures/Sobreventa de stock
```

The rest of the task follows the writing-plans task template: Files, Interfaces, numbered **Acceptance criteria**, TDD steps, and a final **Verify and commit** step with exact commands. In the commit step, stage explicit paths only.

- With no vault, write `**Vault:** none`; with no contracts, `**Contracts:** none`.
- T-000 uses `**Model:** orchestrator`. Its steps are commands rather than TDD, and the integration gate is its check: it has no reviewer.
- Reserved fix tasks get a single `### Tasks T-0NN … T-0MM: Reserved for review fixes` heading with no header line.

## Rules That Make Parallel Workers Possible

- **T-000 belongs to the orchestrator.** It installs every dependency the plan needs, adds scripts, isolates test databases, and runs the gate. Afterwards, workers never touch `package.json` or lockfiles; one that needs a dependency stops with BLOCKED. Check new major versions for module-format breaks: ESM-only packages break CommonJS test runners. T-000 is tooling only: dependencies, scripts, config, test isolation, and framework generators (`nest new`, `create vite`) in a greenfield repo. Shared code is a worker task in wave 1 that replaces the generated files where needed: helpers, module and route registration, test utilities, and the schema and migrations. Tasks in the same wave cannot use each other's output. A wave-1 test that would need another wave-1 utility uses the framework or data source directly.
- **Permission mode is an execution decision.** Record it as `to confirm` (e.g. "workers run with `--permission-mode auto`, authorized by the user at launch"). In a mode that asks for every command, a worker stalls, and the orchestrator must never answer its prompts.
- **Values known only at execution** are written as shell variables or `<…>` in the Orchestration section and marked "resolved at execution". This is the only exemption from writing-plans' "no placeholders" rule.
  - These values: worker pane ids, base commits, the run id's date.
  - Known at plan time and written concretely: COORDINATION_ROOT (resolved at startup) and the orchestrator pane (`$HERDR_PANE_ID`). Mark the pane "re-read at execution", in case another session executes.
- **Contracts before parallelism.** Data shapes, endpoints, error codes and routes are written in the plan before any wave that uses them. A worker that finds a contract impossible reports BLOCKED; it never redefines the contract.
- **Disjoint files within a wave.** Two tasks in the same wave must not create or modify the same file. Shared registration files (app module, router, barrel exports) are either pre-created by a foundation task or listed as "orchestrator resolves trivial merge conflicts".
- **Test isolation per worker.** Each worker gets its own dev DB, test DB and ports: backend and frontend dev servers too, if a task starts them. A browser smoke task states in its Verify step that it may start servers on its own ports. The test script reads the DB name from an env var, for example `E2E_DATABASE_NAME`. The shared test cleanup helper must truncate every table, including tables added by later tasks.
- **Waves.** A wave starts only when its dependencies are integrated and the gate is green. **At most 6 live worker panes** at once, counting implementers, reviewers and fix workers.
  - The cap is the user's standing rule, not a Herdr limit. Only a new explicit instruction from the user changes it; record that as a D-number.
  - A wave wider than the cap stays one wave, marked "queued": each task starts as soon as a pane frees up and its own dependencies are verified. It does not wait for the rest of its wave.

  The cap exists because of:
  - **Pane space:** 6 panes fit as two worker columns of 3, each needing about 60 characters of width. On a narrower terminal, use one column and a cap of 4; check with `herdr pane layout`.
  - **Machine load:** each worker runs installs, test suites and builds against shared services such as Postgres.
  - **Orchestrator throughput:** every task needs acceptance checks, a reviewer, a merge and a full gate, done serially by one session.
  - **Usage limits:** every worker is a full session drawing on the same account quota.

  Plan fewer than 6 when the suites are heavy or the machine is small, and record the reason. Reviewers normally reuse the implementer's pane after `/exit`, so 6 implementers are possible. Planning 4–5 leaves panes for fix workers and for reviewers that keep the implementer alive.
- **ClickUp sync worker.** When the board check found a board and the user confirmed it, plan one long-lived Claude worker, `clickup`, whose only job is to mirror task state to that board through the ClickUp MCP.
  - It is the only writer to ClickUp. Task workers and reviewers never know about ClickUp, and the plan's tasks and packages do not mention it.
  - It covers the whole lifecycle: it creates the tasks and then keeps editing them. The orchestrator starts it in the preflight, before T-000, and sends it batches of events: plan created, plan revised (tasks added, removed, retitled, or acceptance criteria or dependencies changed), task dispatched, report accepted (in review), merged and gate green (integrated), final verification (verified), blocked. Each event names the task ID, the new state or the changed fields, and a one-line note with the evidence (commit, report path, gate result).
  - The worker maps T-IDs to ClickUp task ids in `$report_dir/clickup-map.json`. On "plan created" it creates one task per plan task in the confirmed list, with the title, the acceptance criteria and the dependencies, then reports the map back. On every later event it edits the mapped task: status via `clickup_update_task`, description and dependencies when the plan is revised, and a comment (`clickup_create_task_comment`) with the evidence. A T-ID missing from the map is created first, never duplicated; a task that left the plan is closed with a comment, not deleted.
  - It has no code access, so it runs in `$report_dir` without `--add-dir` of any worktree. Model: `haiku`, because the work is mechanical with a fixed mapping; the fallback is `sonnet`, verified at T-000 like any alias.
  - It counts toward the 6-live-pane cap. Plan at most 5 implementers or reviewers at once, and say so in the Waves line.
  - Its limits are written in the plan: it touches only tasks of this run in the confirmed list; it never deletes tasks or comments, never creates lists or folders, never changes assignees, due dates or other people's tasks, and never writes secrets or PII.
  - If the MCP fails, the worker reports it. The orchestrator queues the pending updates in the scratchpad and continues; no wave waits for ClickUp. The scratchpad records ClickUp sync separately from task status, and never says "synced" without reading the board back.
  - Close its pane at the end of the run, after the last event is applied and read back.
- **E2E, usability and motion task (plans with a UI).** After the last feature task, plan one task `E2E, usability and motion pass`, on `sonnet` (`opus` if the app has payments or auth flows). It is test-and-evidence only: it adds files under the e2e folder and writes a findings report, and never edits app code. Its findings become fix tasks. Its Contracts list includes `Animation guidelines`, copied from `animations-guidelines.md` in this skill.
  - **Functional E2E:** the critical flows of each role, on a desktop viewport and a mobile viewport (touch enabled), against local servers on the worker's own ports.
  - **Usability, as tasks, not pages.** For each role, write 3–5 goal-based tasks in the plan (e.g. "a client books a class and pays"), each with a measurable pass criterion: reachable in at most N steps, a visible response to every action (loading, success, error), error messages that say what to do next, empty, loading and error states present, keyboard reachability and visible focus, touch targets of at least 44px on mobile, and no horizontal scroll at 360px. Each failed criterion is a finding with a screenshot.
  - **Motion audit** against the Animation guidelines, using the "Checks" table in that file: durations, allowed easings, hover transitions gated by `(hover: hover) and (pointer: fine)`, `prefers-reduced-motion` run, origin-aware popovers, transform and opacity only. Run key flows with `reducedMotion: 'reduce'` as well.
  - **Evidence:** a Playwright run with screenshots (and a trace or video for the transitions it judged). Findings are classified Critical, Important or Minor like review findings; a worker may not waive one.
  - **Design improvement notes.** Where the audit shows the design system could be better (inconsistent durations, missing states, weak feedback), the report lists them as proposals, labeled as proposals, never applied by this task.
  - A plan without UI omits the task and says so in the Orchestration section.
- **Closing tasks.** Plan a read-only cross-cutting review on the most capable model, after the last feature task. Reserve IDs after it for fix tasks. Add "Orchestrator closing steps": local run if asked, final gate, vault sync, handoff. Push, PR and merge to a shared branch are listed as "only with explicit authorization".

## Model Per Task

Choose by difficulty, ambiguity, risk and needed context. Do not default every task to the same model.

| Task type | Start with |
|---|---|
| Extraction, classification, mechanical edits with clear criteria | `haiku` |
| Routine implementation, familiar integrations, feature tests, screens against a fixed contract | `sonnet` |
| Architecture, security (auth, tokens, uploads), transactions/locking, hard debugging, cross-cutting review | `opus` (or a more capable model you verified) |

- Give every task a one-line rationale in the model table.
- Reviewer model ≥ implementer model; `opus` reviews security and transaction tasks.
- Use aliases the installed `claude --help` accepts. Its alias list is only examples: an alias missing from it (e.g. `haiku`) is verified at T-000 by starting it once, with the fallback recorded. Use a model newer than `opus` only after checking its suitability in official docs.
- Each task records the requested model; the executor fills in the effective model.
- Write the plan in the language of the spec and the project docs; write the summary in the user's language.

## Summary File

Next to the plan, write `<plan-name>-summary.md` in the user's language. It has one or two sentences on what will be built and a short bullet list of features, with no implementation details. Link the plan from the summary, and link both from the scratchpad.

## Self-Review Additions

Run these on top of writing-plans' self-review:

1. Every task has the header line, and each name in its Contracts list matches a `## ` heading exactly.
2. No file appears in two tasks of the same wave, except declared shared registration files.
3. Every dependency any task uses is installed in T-000.
4. Every task's Verify step runs with only the Worker environment variables.
5. Every Review Focus item names a task, and that task has the test.
6. Decision statuses are honest: `approved` only if the user or the spec approved it; `adopted by orchestrator` only for routine decisions; every scope-changing decision the user has not answered says `to confirm`.
7. ClickUp: the Orchestration section has the sync block (list id, status mapping, launch, event table) or says `**ClickUp:** none` with the reason; the board and task creation are a `to confirm` decision until the user answers; no task, package or Worker environment mentions ClickUp.

8. UI plans: the `## Animation guidelines` contract section exists, every UI task lists it in its Contracts, and the E2E, usability and motion task has usability tasks with measurable criteria for every role. A plan without UI says so.

## Handoff

1. Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<name>.md`, unless the project says otherwise.
2. Save the summary next to it.
3. Update the scratchpad: links, decisions, tasks table with status `planned`, ClickUp board and sync status (`not started`, or `none`), and remaining work.
4. Ask the user to review the plan and confirm every `to confirm` decision.
5. If the user asked only for a plan, stop here. Execution uses **executing-herdr-plans**. This replaces writing-plans' "Execution Handoff" choice between subagent-driven and native execution: do not offer those.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Report files inside each worktree (`.worker/…`) | One private run directory, e.g. `~/.cache/herdr-reports/<run-id>`, mode 0700; it survives worktree cleanup and reviewers find every report there |
| Launch recipe without `--timeout`, permission mode or `--add-dir <report-dir>` | Copy the verified recipe from the template; the worker cannot write its report outside its checkout without `--add-dir` |
| Packages "composed by hand" with excerpts left as `<…>` | Fixed headings + task header line; the orchestrator generates packages with the script |
| A new branch per attempt | One branch per task; fix rounds add commits on top (no amend or rebase) |
| Model chosen once for all tasks | Model per task with a rationale; escalate on repeated failure |
| Dependencies added by whichever task first needs them | All in T-000; a worker needing one stops with BLOCKED |
| No final cross-cutting review | Read-only opus review plus reserved fix task IDs |
| Orchestrator or task workers update ClickUp themselves | Only the `clickup` sync worker writes to the board; the orchestrator sends it events |
| E2E step that only clicks through happy paths and asserts "page loads" | Usability tasks with measurable criteria per role, plus the motion audit; both produce screenshots and a findings report |
| Animation rules left to each UI worker's taste | `## Animation guidelines` as a contract section in every UI task |
| Creating ClickUp tasks while planning, or guessing the list | Ask which list; tasks are created at execution, after the user confirms the decision |
