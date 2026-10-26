# Orchestration section template

Copy these two sections into the plan as two separate `##` sections. "Worker environment" is the one copied into worker packages. Replace every `<…>` with real values, except worker pane ids, base commits and the run id's date, which stay as variables marked "resolved at execution". The permission mode stays `<mode approved by the user>` and is a `to confirm` decision. Remove any line that does not apply. The launch flags shown were verified on herdr 0.9.1 and Claude Code 2.1.x. Check them again against the installed `--help` before writing the plan.

````markdown
## Orchestration (orchestrator-only section)

Workers ignore this section except for "Worker environment".

**Roles.** The orchestrator (this Claude session, pane `<value of $HERDR_PANE_ID>`) owns:
- T-000;
- worktrees and databases (code tasks); the deliverable (findings and document tasks);
- dispatch, and dispatch of reviews;
- merges into `<coordination-branch>` and integration gates;
- `SCRATCHPAD.md` and the vault.

Each worker owns exactly one task in one worktree.

**Waves and DAG** (at most 6 live worker panes, counting reviewers; <lower N and reason, if any>):

| Wave | Tasks (parallel) | Depends on |
|---|---|---|
| 0 | T-000 (orchestrator) | – |
| 1 | T-001 … · T-002 … · T-003 … | T-000 |
| … | … | … |
| n-1 | T-0NN E2E, usability and motion pass (tests and findings report only; omit and say so if the plan has no UI) | every feature task |
| n | T-0NN consolidation (`document`; only plans with findings or document tasks) | every findings and document task |
| n+1 | T-0NN cross-cutting review (read-only; in a plan without code a `findings` task over the deliverable, in a mixed plan over the integrated branch and the deliverable) | everything above, the E2E, usability and motion pass, and the consolidation |
| n+2 | Fix tasks from the review (T-0NN+1…) · vault sync (orchestrator) | review |

In a plan with no findings or document tasks, drop the consolidation row: the review is wave n and the fixes are wave n+1. In a plan with them, the closing order is consolidation, then review, then fixes.

**Model policy** (verify the effective model from the worker's status line after start):

| Task | Kind | Model | Rationale |
|---|---|---|---|
| T-001 | code | opus | auth/JWT/throttling: security-sensitive |
| T-002 | code | sonnet | entities fully specified in the Data contract |
| T-003 | findings | opus | security audit of the auth module |
| … | … | … | … |
| Per-task reviewers | – | opus for <security/transaction tasks>, sonnet otherwise | reviewer at least as capable as the implementer |

**Worker launch** (verified flags on Claude Code <version> / herdr <version>):

```bash
run_id=<project>-<yyyymmdd>
report_dir="$HOME/.cache/herdr-reports/$run_id"; mkdir -p -m 700 "$report_dir"
wt_root=<COORDINATION_ROOT>.worktrees
# per task (example T-004):
git -C "$COORDINATION_ROOT" worktree add "$wt_root/T-004" -b feature/<prefix>-T-004 <coordination-branch>
sed -e 's/^DATABASE_NAME=.*/DATABASE_NAME=<app>_t004/' -e 's/^PORT=.*/PORT=3104/' "$COORDINATION_ROOT/.env" > "$wt_root/T-004/.env"
<create dev and test DBs, e.g. docker exec <pg-container> createdb -U <user> <app>_t004 and <app>_t004_test>
(cd "$wt_root/T-004" && pnpm install --frozen-lockfile)
split=$(herdr pane split --pane <worker-column-pane> --direction down --cwd "$wt_root/T-004" --env E2E_DATABASE_NAME=<app>_t004_test --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')
# reusing a pane freed by /exit instead of splitting:
# herdr pane run "$pane" "cd $wt_root/T-004 && export E2E_DATABASE_NAME=<app>_t004_test"
herdr agent start t004 --kind claude --pane "$pane" --timeout 120000 -- --model sonnet --permission-mode <mode approved by the user> --add-dir "$report_dir" -n "T-004 <short label>"
herdr agent prompt t004 "Read $report_dir/T-004.package.md and execute it exactly. Write your report to $report_dir/T-004.md and end with STATUS and REPORT lines." --wait --timeout 3600000
```

**Non-code worker launch** (findings and document tasks: no worktree, no database, no `--env`; example T-003):

```bash
split=$(herdr pane split --pane <worker-column-pane> --direction down --cwd <COORDINATION_ROOT> --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')
herdr agent start t003 --kind claude --pane "$pane" --timeout 120000 -- --model opus --permission-mode dontAsk --allowedTools "<verified allowlist>" --add-dir "$report_dir" -n "T-003 <short label>"
herdr agent prompt t003 "Read $report_dir/T-003.package.md and execute it exactly. Write your report to $report_dir/T-003.md and end with STATUS and REPORT lines." --wait --timeout 3600000
```

`<verified allowlist>` is the read tools, the read-only commands the plan names, and Write/Edit only under `$report_dir`, in the syntax the installed `claude --help` accepts (checked at preflight). Reviewers of these tasks launch the same way, with `-n "T-003 review"`.

**Reviewer launch.** Same flags, `-n "T-0NN review"`, on the reviewer model from the table, with the prompt "Read $report_dir/T-0NN.review-package.md and execute it exactly." The reviewer runs in a new pane, or in the implementer's pane after `/exit`. The review package makes it read-only; it writes `$report_dir/T-0NN.review.md`.

**Layout.** Two worker columns of at most 3 panes each, to the right of the orchestrator:
- worker 1: `herdr pane split --pane <orchestrator-pane> --direction right --no-focus` creates column A;
- worker 2: split column A's first pane `right`, creating column B;
- later workers: split `down` in whichever column has fewer panes.

Close a worker pane only after its report is accepted and no follow-up turn is needed.

**Task package** (`$report_dir/<task>.package.md`) is the delegation contract filled in, plus:
- the task section, verbatim;
- Decisions, Global Constraints, Review Focus and Worker environment;
- the contract sections listed in the task header;
- vault excerpts quoted by the orchestrator.

Generate it with `bash <executing-herdr-plans skill dir>/scripts/make-package.sh`; for the read-only cross-cutting review of code, add `--role review`. For findings and document tasks it reads `--kind` from the task header; the cross-cutting review of a plan without code is a `findings` task, so it has no `--role review`.

**Deliverable** (plans with findings or document tasks; remove this block otherwise):
- Path: `<COORDINATION_ROOT>/deliverables/<run-id>/`, with `parts/`, `evidence/`, `<name>.md` and, if the format is `html`, `<name>.html`.
- Format: `<md | html>`. The `.md` is the source; the `.html` is generated from it, never hand-edited.
- Commit decision D`<n>` `to confirm`: committed by the orchestrator on `<coordination-branch>`, or, for sensitive evidence, the same layout outside the repo and not committed.

**ClickUp sync** (remove this block and write `**ClickUp:** none` plus the reason if there is no board). Rules: the "ClickUp sync worker" rule in writing-herdr-plans.
- Board: list `<list id>` (`<list name>`), decision D`<n>` `to confirm`. The only writer is the `clickup` worker; it counts toward the 6-pane cap.
- Status mapping (exact names from the list):

  | Task state | ClickUp status |
  |---|---|
  | planned | `<status>` |
  | in progress | `<status>` |
  | in review | `<status>` |
  | integrated | `<status>` |
  | verified | `<status>` |
  | blocked | `<status>` |

- Launch (model `haiku`, fallback `sonnet`; `<tool allowance>` is the verified `--allowedTools "mcp__claude_ai_ClickUp__*"` or the permission mode the user approved):

  ```bash
  split=$(herdr pane split --pane <worker-column-pane> --direction down --cwd "$report_dir" --no-focus)
  pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')
  herdr agent start clickup --kind claude --pane "$pane" --timeout 120000 -- --model haiku <tool allowance> -n "ClickUp sync"
  ```

- First prompt: the confirmed list id, the status mapping, the rules (touch only tasks of this run in that list; no deletes, no lists or folders, no assignees or due dates; no secrets or PII), and the instruction to keep `$report_dir/clickup-map.json`.
- Events (one prompt per batch, `--wait`): `plan created` (create one task per plan task: title, acceptance criteria, dependencies) · `plan revised` (edit title, description, dependencies; create new tasks; close removed ones with a comment) · `dispatched` · `in review` · `integrated` · `verified` · `blocked`. Each line: `T-0NN → <state> | <evidence>`.
- After each batch the worker reads the affected tasks back and reports `STATUS` and the map. Record the result in the scratchpad's ClickUp line; on failure, queue the events there and continue.

**Acceptance per task.** Code: as below. Findings and document: `kinds/<kind>.md` in executing-herdr-plans. For code, all of these must hold:
- the worker state has settled;
- the report says PASS;
- `git -C <worktree> diff --stat <base>...HEAD` touches only the task's declared files;
- the orchestrator has re-run the task's verification commands in the worktree;
- a separate reviewer reports no Critical or Important findings, or they were fixed and verified again.

**Integration gate** (orchestrator, coordination checkout, after each `git merge --no-ff feature/<prefix>-<task>`). Findings and document: the plan's check commands over `deliverables/<run-id>/parts/` (unique IDs, filled evidence fields, outline headings present).

```bash
<full gate, e.g. pnpm lint && pnpm test && pnpm test:e2e && pnpm build>
```

**Final verification** (UI plans, run after the E2E, usability and motion task is merged): `<e2e command, desktop and mobile projects>`. It must leave screenshots and the findings report in `$report_dir`. Critical and Important findings become fix tasks; Minor ones are recorded as debt.

## Worker environment

- You work in your own git worktree on branch `feature/<prefix>-<task-id>`, created from `<coordination-branch>`. Your worktree root contains its own `.env` (dev database `<app>_<task>`, port `31NN`) and its own `node_modules`.
- <Shared services, e.g. Postgres in container `<name>`.> Your test database name is in the shell variable `E2E_DATABASE_NAME`. Never touch other databases.
- Run commands from the worktree root: `<package-manager> --filter <pkg> <script>`.
- Do not start long-running dev servers unless your task's verification says so, and stop them before reporting.
````
