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
4. **Tooling, verified, not remembered.** Run `herdr --help`, `herdr agent`, `claude --help`, `herdr integration status`, and `herdr pane layout --pane "$HERDR_PANE_ID"` (your pane id and the terminal width). Record the exact launch flags you will put in the plan.
5. **Decisions.** List every decision the spec leaves open.
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
| `## Orchestration (orchestrator-only section)` | Waves/DAG, model table, launch recipe, acceptance, integration gate. Template: `orchestration-section-template.md`. | no |
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

## Handoff

1. Save the plan to `docs/superpowers/plans/YYYY-MM-DD-<name>.md`, unless the project says otherwise.
2. Save the summary next to it.
3. Update the scratchpad: links, decisions, tasks table with status `planned`, and remaining work.
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
