# Shop API Security Audit Implementation Plan

> **For agentic workers:** executed with executing-herdr-plans; a worker implements only its own task.

**Goal:** audit the authentication and order modules of the shop API and deliver one document with the confirmed findings and a recommendation.

**Architecture:** two read-only findings workers examine disjoint modules in parallel; one document worker consolidates their integrated reports into the deliverable; a read-only review checks the deliverable; fix slots are reserved for the code that will fix what is found.

**Sources and tools:** repo `/srv/acme/shop-api` (read-only), `git`, `rg`, `jq`. No network, no production access.

**Spec:** the request "audit auth and orders in shop-api before the March release" (conversation, 2026-10-26). **Vault:** none (the vault check found no notes for this project).

## Decisions recorded for this plan

| # | Decision | Source | Status |
|---|---|---|---|
| D1 | Deliverable: `/srv/acme/shop-audit/deliverables/<run-id>/` with `parts/`, `evidence/`, `shop-api-audit.md` and `shop-api-audit.html`, committed by the orchestrator on `audit/main` | Orchestrator proposal | to confirm |
| D2 | Workers run with `--permission-mode dontAsk` and a read-only `--allowedTools` list | Orchestrator proposal | to confirm |
| D3 | Workers have no network access and no access to production or real accounts | Orchestrator proposal | to confirm |
| D4 | Credentials: none are needed; a secret met in the sources is reported by file and type, never copied | Orchestrator proposal | to confirm |
| D5 | Finding IDs are `<TASK>-F<NN>`; severities follow the Severity scale | Orchestrator | adopted by orchestrator |
| D6 | ClickUp: none, the board check found no board for this project | Board check | adopted by orchestrator |

## Global Constraints

- Read-only: no worker edits, creates or deletes anything in `/srv/acme/shop-api`; no worker runs a command that changes state.
- A finding without evidence is not a finding. Evidence is a `file:line`, a command with its output, or a URL.
- A secret found is reported by location and type, never copied into a report, a part or an evidence file.
- Finding IDs are `<TASK>-F<NN>` (for example `T-001-F01`); a worker numbers only its own findings.
- Two findings tasks in one wave never examine the same module.
- Workers write only under their report directory: the report, `evidence/<TASK>/` or `parts/<TASK>.md`.
- The deliverable is `shop-api-audit.md`; `shop-api-audit.html` is generated from it as one file with inline CSS and no network loads, never hand-edited.
- The orchestrator copies each findings report, with the reviewer's verdicts applied, to `deliverables/<run-id>/parts/<TASK>.md`; the consolidation reads only that folder.

## Review Focus

1. [T-001, T-002] Every finding has its evidence fields filled and an evidence file that exists.
2. [T-001, T-002] Findings are reproduced twice before they are written down; what does not reproduce is listed under "Not reproduced".
3. [T-003] No finding is changed or dropped by the consolidation; contradictions between parts are listed, not resolved.
4. [T-004] Every claim of the deliverable traces to a finding ID with its evidence.

## Orchestration (orchestrator-only section)

Workers ignore this section except for "Worker environment".

**Roles.** The orchestrator (this Claude session, pane `$HERDR_PANE_ID`, re-read at execution) owns:
- T-000;
- the deliverable;
- dispatch, and dispatch of reviews;
- merges into `audit/main` and integration gates;
- `SCRATCHPAD.md` and the vault.

Each worker owns exactly one task.

`COORDINATION_ROOT` is `/srv/acme/shop-audit`, fixed for the run.

**Waves and DAG** (at most 6 live worker panes, counting reviewers):

| Wave | Tasks (parallel) | Depends on |
|---|---|---|
| 0 | T-000 (orchestrator) | – |
| 1 | T-001 auth audit · T-002 orders audit | T-000 |
| 2 | T-003 consolidation (`document`) | T-001, T-002 |
| 3 | T-004 cross-cutting review (`findings` task over the deliverable) | T-003 |
| 4 | Fix tasks from the review and from T-001, T-002 (T-005 … T-007, reserved) | T-004 |

The closing order is consolidation, then review, then fixes. There is no UI, so there is no E2E pass.

**Model policy** (verify the effective model from the worker's status line after start):

| Task | Kind | Model | Rationale |
|---|---|---|---|
| T-001 | findings | opus | security audit of the auth module |
| T-002 | findings | sonnet | business-logic audit against a fixed findings format |
| T-003 | document | opus | consolidates two reports into one deliverable without changing a claim |
| T-004 | findings | opus | cross-cutting review of the deliverable |
| Per-task reviewers | – | opus for T-001 and T-003, sonnet for T-002 | reviewer at least as capable as the author |

**Non-code worker launch** (findings and document tasks: no worktree, no database, no `--env`; example T-003):

```bash
run_id=shop-audit-<yyyymmdd>   # resolved at execution
report_dir="$HOME/.cache/herdr-reports/$run_id"; mkdir -p -m 700 "$report_dir"
split=$(herdr pane split --pane <worker-column-pane> --direction down --cwd /srv/acme/shop-audit --no-focus)
pane=$(printf '%s' "$split" | jq -r '.result.pane.pane_id')
herdr agent start t003 --kind claude --pane "$pane" --timeout 120000 -- --model opus --permission-mode dontAsk --allowedTools "Read,Grep,Glob,Bash(rg:*),Bash(git -C /srv/acme/shop-api log:*),Bash(git -C /srv/acme/shop-api status:*),Write($report_dir/**),Edit($report_dir/**)" --add-dir "$report_dir" --add-dir /srv/acme/shop-api -n "T-003 consolidation"
herdr agent prompt t003 "Read $report_dir/T-003.package.md and execute it exactly. Write your report to $report_dir/T-003.md and end with STATUS and REPORT lines." --wait --timeout 3600000
```

The allowlist is checked against the installed `claude --help` at preflight. Reviewers launch the same way, with `-n "T-0NN review"`.

**Reviewer launch.** Same flags, `-n "T-0NN review"`, on the reviewer model from the table, with the prompt "Read $report_dir/T-0NN.review-package.md and execute it exactly." The reviewer runs in a new pane, or in the author's pane after `/exit`; it writes `$report_dir/T-0NN.review.md`.

**Layout.** Two worker columns of at most 3 panes each, to the right of the orchestrator; close a worker pane only after its report is accepted and no follow-up turn is needed.

**Task package** (`$report_dir/<task>.package.md`) is generated with `bash <executing-herdr-plans skill dir>/scripts/make-package.sh`, which reads `--kind` from the task header. The cross-cutting review is a `findings` task, so it has no `--role review`.

**Deliverable:**
- Path: `/srv/acme/shop-audit/deliverables/<run-id>/`, with `parts/`, `evidence/`, `shop-api-audit.md` and `shop-api-audit.html`.
- Format: `html`. The `.md` is the source; the `.html` is generated from it, never hand-edited.
- Commit decision D1 `to confirm`: committed by the orchestrator on `audit/main`, or, for sensitive evidence, the same layout outside the repo and not committed.

**ClickUp:** none, the board check found no board for this project (D6).

**Acceptance per task.** Findings and document: `kinds/<kind>.md` in executing-herdr-plans.

**Integration gate** (orchestrator, coordination checkout, after each report is integrated into `deliverables/<run-id>/parts/`):

```bash
cd /srv/acme/shop-audit/deliverables/<run-id>
cat parts/T-00[12].md | grep -o '^| T-00[12]-F[0-9]*' | sort | uniq -d    # no output: unique IDs
awk -F'|' '/^\| T-00[12]-F/ { for (i = 2; i <= 7; i++) if ($i ~ /^[[:space:]]*$/) bad++ } END { print (bad ? "EMPTY CELL" : "cells ok") }' parts/T-00[12].md
for h in '## 1 Executive summary' '## 2 Confirmed findings' '## 3 Corrected false positives' '## 4 Recommendation'; do grep -Fxq "$h" shop-api-audit.md || echo "MISSING $h"; done
grep -Eic '<script|<link[^>]*href="https?:|src="https?:' shop-api-audit.html
```

Expected: no output from the first command, `cells ok`, no `MISSING`, and `0`. The last two run once the consolidation is integrated.

## Worker environment

- You audit or write; you change no source. Your working directory is `/srv/acme/shop-audit`. Read `/srv/acme/shop-api` (added to your session with `--add-dir`) freely; never write there.
- You write only your own files under the report directory: `<report-dir>/T-0NN.md`, `<report-dir>/evidence/T-0NN/` or `<report-dir>/parts/T-0NN.md` (the real paths are in your package). Read under `deliverables/` only when your task's Sources name it; never write there.
- No network: you make no requests to any host.
- No credentials are needed. Never touch `.env` files, `SCRATCHPAD.md`, other workers' reports or dependency manifests.
- Secrets you meet: report the file and the type, never the value.

## Findings format

One row per finding, in the worker's report under `## Findings`:

| ID | Severity | Title | Evidence | Impact | Recommendation |
|---|---|---|---|---|---|
| T-001-F01 | Critical | Refresh tokens survive password reset | `src/auth/refresh.service.ts:58`; request and response in `evidence/T-001/F01.txt` | A stolen refresh token stays valid after the owner resets the password | Revoke all refresh tokens in `resetPassword()` |

- ID: `<TASK>-F<NN>`; a worker numbers only its own findings.
- Severity: a value of the Severity scale, exactly as written.
- Evidence: `file:line`, command plus output, URL, or screenshot path under `evidence/<TASK>/`. Never empty.
- Problems that did not reproduce go under `## Not reproduced`, outside the table.

## Severity scale

- **Critical:** exploitable now, or loses data, money or access, with no precondition beyond a normal user. Fix before anything ships.
- **Important:** a real defect or exposure that needs a precondition, or breaks a documented requirement. Fix within this plan.
- **Minor:** hygiene, naming, hardening, or a low-impact deviation. Recorded as debt.

## Document outline

| Section | Exact heading | Owner | Content |
|---|---|---|---|
| 1 | `## 1 Executive summary` | T-003 | Scope, counts per severity, the three findings that matter most |
| 2 | `## 2 Confirmed findings` | T-003 | The confirmed findings of T-001 and T-002, from `parts/T-001.md` and `parts/T-002.md`, in ID order |
| 3 | `## 3 Corrected false positives` | T-003 | The "Corrected false positives" sections of both parts |
| 4 | `## 4 Recommendation` | T-003 | What to fix first and what to record as debt |

## Style guide

- English, present tense, no first person. Numbers with units and a date.
- One claim per line. Opinions start with `Note:`.
- Finding IDs are written in full (`T-001-F01`) wherever a finding is mentioned.

## Tasks

### Task T-000: Preflight and baselines

**Model:** orchestrator · **Depends on:** none · **Contracts:** none · **Vault:** none

- [ ] **Step 1:** create the report directory and its folders.
  ```bash
  mkdir -p "$report_dir/parts" "$report_dir/evidence"
  ```
- [ ] **Step 2:** prove read-only access to the source and record the baseline. The scope check later compares against this baseline, not against "empty", because the orchestrator writes the plan and the scratchpad in the coordination repo.
  ```bash
  git -C /srv/acme/shop-api status --porcelain > "$report_dir/baseline-shop-api.status"
  git -C /srv/acme/shop-api rev-parse HEAD > "$report_dir/baseline-shop-api.head"
  git -C /srv/acme/shop-api status --porcelain -- src/auth src/users > "$report_dir/baseline-T-001.status"
  git -C /srv/acme/shop-api status --porcelain -- src/orders src/stock > "$report_dir/baseline-T-002.status"
  git -C /srv/acme/shop-audit status --porcelain -- deliverables > "$report_dir/baseline-deliverables.status"
  ```
- [ ] **Step 3:** check the tools the tasks name and the launch flags.
  ```bash
  command -v rg jq git
  claude --help | grep -E 'allowedTools|permission-mode'
  ```
- [ ] **Step 4:** verify the effective model of each alias in the model table by starting it once; record the result in the scratchpad.

### Task T-001: Audit authentication in the shop API

**Kind:** findings · **Model:** opus · **Depends on:** T-000 · **Parallel with:** T-002 · **Contracts:** Findings format, Severity scale · **Vault:** none

**Scope:** `/srv/acme/shop-api/src/auth/` and `/srv/acme/shop-api/src/users/`: login, token issue and refresh, password reset, session invalidation. Not examined: orders, payments, infrastructure.
**Sources:** repo `/srv/acme/shop-api` (read-only). No network.

**Acceptance criteria:**
1. Every in-scope entry point (route or function) is listed in the report as covered, with the finding IDs it produced or "no finding".
2. Every finding is in the Findings format, with a severity from the Severity scale and an evidence file under `<report-dir>/evidence/T-001/`.
3. Every finding was reproduced a second time before being written down.

- [ ] **Step 1: Survey.** List the in-scope entry points with `rg -n "@(Get|Post|Put|Delete)\(" /srv/acme/shop-api/src/auth /srv/acme/shop-api/src/users`. Read each one and note what to check.
- [ ] **Step 2: Verify each finding.** For each suspected problem, run the command or read the code that shows it, save the exact output to `<report-dir>/evidence/T-001/F<NN>.txt`, and run it again. A problem you cannot reproduce is not a finding: list it under "Not reproduced".
- [ ] **Step 3: Write in the Findings format.** One row per finding in `<report-dir>/T-001.md`, IDs `T-001-F01`, `T-001-F02`, … in the order found. Add the scope covered and not covered, and the commands run.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^| T-001-F' <report-dir>/T-001.md
  awk -F'|' '/^\| T-001-F/ { for (i = 2; i <= 7; i++) if ($i ~ /^[[:space:]]*$/) bad++ } END { print (bad ? "EMPTY CELL" : "cells ok") }' <report-dir>/T-001.md
  grep -o 'evidence/T-001/[A-Za-z0-9._-]*' <report-dir>/T-001.md | sort -u | while read -r f; do test -s "<report-dir>/$f" || echo "MISSING $f"; done
  git -C /srv/acme/shop-api status --porcelain -- src/auth src/users | diff - <report-dir>/baseline-T-001.status && echo "scope untouched"
  ```
  Expected: the first count equals the number of findings you wrote, then `cells ok`, no `MISSING`, `scope untouched`.

### Task T-002: Audit orders in the shop API

**Kind:** findings · **Model:** sonnet · **Depends on:** T-000 · **Parallel with:** T-001 · **Contracts:** Findings format, Severity scale · **Vault:** none

**Scope:** `/srv/acme/shop-api/src/orders/` and `/srv/acme/shop-api/src/stock/`: order creation, totals, stock reservation, cancellation. Not examined: authentication, payments, infrastructure.
**Sources:** repo `/srv/acme/shop-api` (read-only). No network.

**Acceptance criteria:**
1. Every in-scope entry point (route or function) is listed in the report as covered, with the finding IDs it produced or "no finding".
2. Every finding is in the Findings format, with a severity from the Severity scale and an evidence file under `<report-dir>/evidence/T-002/`.
3. Every finding was reproduced a second time before being written down.

- [ ] **Step 1: Survey.** List the in-scope entry points with `rg -n "@(Get|Post|Put|Delete)\(" /srv/acme/shop-api/src/orders /srv/acme/shop-api/src/stock`. Read each one and note what to check.
- [ ] **Step 2: Verify each finding.** For each suspected problem, run the command or read the code that shows it, save the exact output to `<report-dir>/evidence/T-002/F<NN>.txt`, and run it again. A problem you cannot reproduce is not a finding: list it under "Not reproduced".
- [ ] **Step 3: Write in the Findings format.** One row per finding in `<report-dir>/T-002.md`, IDs `T-002-F01`, `T-002-F02`, … in the order found. Add the scope covered and not covered, and the commands run.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^| T-002-F' <report-dir>/T-002.md
  awk -F'|' '/^\| T-002-F/ { for (i = 2; i <= 7; i++) if ($i ~ /^[[:space:]]*$/) bad++ } END { print (bad ? "EMPTY CELL" : "cells ok") }' <report-dir>/T-002.md
  grep -o 'evidence/T-002/[A-Za-z0-9._-]*' <report-dir>/T-002.md | sort -u | while read -r f; do test -s "<report-dir>/$f" || echo "MISSING $f"; done
  git -C /srv/acme/shop-api status --porcelain -- src/orders src/stock | diff - <report-dir>/baseline-T-002.status && echo "scope untouched"
  ```
  Expected: the first count equals the number of findings you wrote, then `cells ok`, no `MISSING`, `scope untouched`.

### Task T-003: Consolidate the deliverable

**Kind:** document · **Model:** opus · **Depends on:** T-001, T-002 integrated · **Parallel with:** none · **Contracts:** Document outline, Style guide · **Vault:** none

**Deliverable format:** html. Generate `<report-dir>/parts/T-003.html` from the `.md`.
**Part:** the whole document, written as `<report-dir>/parts/T-003.md` (the orchestrator places it as `shop-api-audit.md` in the deliverable). **Sources:** `deliverables/<run-id>/parts/` (read only): the integrated findings parts of T-001 and T-002 (cited by finding ID).

**Acceptance criteria:**
1. The document has an executive summary, the confirmed findings of each part, a "Corrected false positives" section (gathered from the integrated findings parts) and the recommendation.
2. No part's claim is changed; contradictions between parts are listed in the report instead of silently resolved.
3. `<report-dir>/parts/T-003.html` is generated from the `.md`: one file, inline CSS, no network loads.

- [ ] **Step 1: Read the parts.** Read every file in `deliverables/<run-id>/parts/`: the confirmed findings and the "Corrected false positives" sections of both parts.
- [ ] **Step 2: Write the document** in the order of criterion 1, using exactly the headings of the Document outline. Keep each finding's ID, row and evidence, and cite the finding ID for each claim taken from a part.
- [ ] **Step 3: Render.** Generate the `.html` from the `.md`. Never edit it by hand: fix the `.md` and generate again.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^## ' <report-dir>/parts/T-003.md
  for h in '## 1 Executive summary' '## 2 Confirmed findings' '## 3 Corrected false positives' '## 4 Recommendation'; do grep -Fxq "$h" <report-dir>/parts/T-003.md || echo "MISSING $h"; done
  grep -Eic '<script|<link[^>]*href="https?:|src="https?:' <report-dir>/parts/T-003.html
  ```
  Expected: `4` (the fixed sections; the outline has no area sections), no `MISSING`, and `0`.

### Task T-004: Review the deliverable

**Kind:** findings · **Model:** opus · **Depends on:** T-003 integrated · **Parallel with:** none · **Contracts:** Findings format, Severity scale · **Vault:** none

**Scope:** `/srv/acme/shop-audit/deliverables/<run-id>/shop-api-audit.md` and `shop-api-audit.html`, read against `deliverables/<run-id>/parts/` and `deliverables/<run-id>/evidence/`: coherence, contradictions between sections, claims without evidence, severity mismatches. Not examined: the shop API source itself.
**Sources:** `deliverables/<run-id>/` (read-only). No network.

**Acceptance criteria:**
1. Every section of the deliverable is listed in the report as covered, with the finding IDs it produced or "no finding".
2. Every finding is in the Findings format, with a severity from the Severity scale and an evidence file under `<report-dir>/evidence/T-004/`.
3. Every finding was reproduced a second time before being written down.

- [ ] **Step 1: Survey.** List the sections of the deliverable with `grep -n '^## ' /srv/acme/shop-audit/deliverables/<run-id>/shop-api-audit.md`. For each finding ID in the deliverable, find its row in `parts/`.
- [ ] **Step 2: Verify each finding.** For each suspected problem (a claim with no finding ID, a severity that differs from its part, two sections that disagree), quote both places, save them to `<report-dir>/evidence/T-004/F<NN>.txt`, and check them again. A problem you cannot reproduce is not a finding: list it under "Not reproduced".
- [ ] **Step 3: Write in the Findings format.** One row per finding in `<report-dir>/T-004.md`, IDs `T-004-F01`, `T-004-F02`, … in the order found. Add the sections covered and not covered, and the commands run.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^| T-004-F' <report-dir>/T-004.md
  awk -F'|' '/^\| T-004-F/ { for (i = 2; i <= 7; i++) if ($i ~ /^[[:space:]]*$/) bad++ } END { print (bad ? "EMPTY CELL" : "cells ok") }' <report-dir>/T-004.md
  grep -o 'evidence/T-004/[A-Za-z0-9._-]*' <report-dir>/T-004.md | sort -u | while read -r f; do test -s "<report-dir>/$f" || echo "MISSING $f"; done
  git -C /srv/acme/shop-audit status --porcelain -- deliverables | diff - <report-dir>/baseline-deliverables.status && echo "deliverable untouched"
  ```
  Expected: the first count equals the number of findings you wrote, then `cells ok`, no `MISSING`, `deliverable untouched`.

### Tasks T-005 … T-007: Reserved for fixes from T-001, T-002

## Self-review

- Every task has the header line; every name in a Contracts list matches a `## ` heading exactly.
- Every Review Focus item names a task, and that task's Verify or criteria cover it.
- Decision statuses: D1 to D4 change scope or access and are `to confirm`; D5 and D6 are routine.
- ClickUp: none, with the reason, in the Orchestration section; no task, package or Worker environment mentions it.
- Findings: every findings task lists `Findings format` and `Severity scale`; T-001 and T-002 scopes do not overlap; T-000 records a baseline per source.
- Document: T-003 is the only consolidation task, depends on every part, and its Verify runs the `grep` check for the html format; the cross-cutting review T-004 comes after it, then the reserved slots T-005 to T-007.
