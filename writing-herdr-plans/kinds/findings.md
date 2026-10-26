# Findings tasks

Read this when the plan has findings tasks (audits, QA passes, reviews of something that already exists).

## Task steps

A findings task replaces the TDD steps of writing-plans with the template below. The worker reads the sources and writes only its report and evidence: no worktree, no branch, no commits. `<report-dir>` is known only at execution (the package gives the real path); everything else is written concretely.

````markdown
### Task T-002: Audit authentication in the API

**Kind:** findings · **Model:** opus · **Depends on:** T-000 · **Parallel with:** T-003 · **Contracts:** Findings format, Severity scale · **Vault:** none

**Scope:** `/srv/acme/api/src/auth/` and `/srv/acme/api/src/users/`: login, token issue and refresh, password reset, session invalidation. Not examined: billing, the web client, infrastructure.
**Sources:** repo `/srv/acme/api` (read-only); staging URL `https://staging.acme.example` (GET only); AWS account by profile `acme-readonly`.

**Acceptance criteria:**
1. Every in-scope entry point (route or function) is listed in the report as covered, with the finding IDs it produced or "no finding".
2. Every finding is in the Findings format, with a severity from the Severity scale and an evidence file under `<report-dir>/evidence/T-002/`.
3. Every finding was reproduced a second time before being written down.

- [ ] **Step 1: Survey.** List the in-scope entry points with `rg -n "@(Get|Post|Put|Delete)\(" /srv/acme/api/src/auth`. Read each one and note what to check.
- [ ] **Step 2: Verify each finding.** For each suspected problem, run the command, request or read that shows it, save the exact output to `<report-dir>/evidence/T-002/F<NN>.txt`, and run it again. A problem you cannot reproduce is not a finding: list it under "Not reproduced".
- [ ] **Step 3: Write in the Findings format.** One row per finding in `<report-dir>/T-002.md`, IDs `T-002-F01`, `T-002-F02`, … in the order found. Add the scope covered and not covered, and the commands run.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^| T-002-F' <report-dir>/T-002.md
  awk -F'|' '/^\| T-002-F/ { for (i = 2; i <= 7; i++) if ($i ~ /^[[:space:]]*$/) bad++ } END { print (bad ? "EMPTY CELL" : "cells ok") }' <report-dir>/T-002.md
  grep -o 'evidence/T-002/[A-Za-z0-9._-]*' <report-dir>/T-002.md | sort -u | while read -r f; do test -s "<report-dir>/$f" || echo "MISSING $f"; done
  git -C /srv/acme/api status --porcelain -- src/auth src/users | diff - <report-dir>/baseline-T-002.status && echo "scope untouched"
  ```
  Expected: the first count equals the number of findings you wrote, then `cells ok`, no `MISSING`, `scope untouched`.
````

## Rules for findings workers

- **Read-only.** A findings task never edits, creates or deletes anything in the sources and never runs a command that changes state (no `POST` against a real account, no `terraform apply`). It writes only `<report-dir>/<TASK>.md` and `<report-dir>/evidence/<TASK>/`.
- **Evidence or it is not a finding.** Evidence is a `file:line`, a command with its output, a URL, or a screenshot path. A secret found is reported by location and type, never copied into the report or the evidence.
- **Non-overlapping scopes within a wave.** Two findings tasks in the same wave must not examine the same module, account or area. A scope that must be seen twice is two sequential tasks, or one task.
- **Credentials and access** appear in the plan only by variable or profile name. Production access, real accounts and worker network access are `to confirm` decisions.
- **Deliverable.** The plan records the deliverable decision (path, format, committed or not) as `to confirm` and has a consolidation task (kind `document`, last wave: see `kinds/document.md`). When a findings task is integrated, the orchestrator copies its report, with the reviewer's verdicts applied (confirmed findings, plus a "Corrected false positives" section with the not reproduced ones), to `deliverables/<run-id>/parts/<TASK>.md`; the consolidation reads only that folder.
- **Closing order:** consolidation task, then the cross-cutting review, then the reserved fix tasks. In a plan without code, the cross-cutting review is a `findings` task over the deliverable (coherence, contradictions, claims without evidence). In a mixed plan the review is two tasks: the code review (`--role review`) of the integrated branch and a `findings` task over the deliverable.
- **Mixed plans.** The code that fixes findings does not exist yet. Reserve its IDs: `### Tasks T-0NN … T-0MM: Reserved for fixes from T-0XX`. After the findings wave, the orchestrator writes each fix task in full ("New task IDs" in executing-herdr-plans) with its own D-number.

## Contracts

Write the ones the plan needs as `##` sections; a task lists them by exact heading.

**`## Findings format`** (every findings task lists it)

```markdown
## Findings format

One row per finding, in the worker's report under `## Findings`:

| ID | Severity | Title | Evidence | Impact | Recommendation |
|---|---|---|---|---|---|
| T-002-F01 | Critical | Refresh tokens survive password reset | `src/auth/refresh.service.ts:58`; request and response in `evidence/T-002/F01.txt` | A stolen refresh token stays valid after the owner resets the password | Revoke all refresh tokens in `resetPassword()` |

- ID: `<TASK>-F<NN>`; a worker numbers only its own findings.
- Severity: a value of the Severity scale, exactly as written.
- Evidence: `file:line`, command plus output, URL, or screenshot path under `evidence/<TASK>/`. Never empty.
- Problems that did not reproduce go under `## Not reproduced`, outside the table.
```

**`## Severity scale`** (every findings task lists it)

```markdown
## Severity scale

- **Critical:** exploitable now, or loses data, money or access, with no precondition beyond a normal user. Fix before anything ships.
- **Important:** a real defect or exposure that needs a precondition, or breaks a documented requirement. Fix within this plan.
- **Minor:** hygiene, naming, hardening, or a low-impact deviation. Recorded as debt.
```

**`## Control list`** (compliance audits only). One row per control, so every worker checks the same list:

```markdown
## Control list

| Control | Requirement | How to check |
|---|---|---|
| AC-01 | Passwords are hashed with a slow hash | Read `src/auth/password.ts`; confirm bcrypt or argon2 with a cost parameter |
| AC-02 | Sessions expire after at most 24 hours | Read `src/auth/session.config.ts`; confirm the TTL value |
```

A task lists the controls in its scope by ID. A control with no finding is reported as "met", with its evidence.

## T-000 for this kind

T-000 stays with the orchestrator. For a plan with findings tasks it:

1. creates `<report-dir>/parts` and `<report-dir>/evidence`;
2. proves read-only access to every source and records the baseline:
   - repo: `git -C /srv/acme/api status --porcelain > <report-dir>/baseline-api.status` and `git -C /srv/acme/api rev-parse HEAD > <report-dir>/baseline-api.head`. The scope check later compares against this baseline, not against "empty", because the orchestrator writes the plan and the scratchpad in the same repo;
   - each findings task's Scope paths, the same way: `git -C /srv/acme/api status --porcelain -- src/auth src/users > <report-dir>/baseline-T-002.status`. The worker's Verify compares only these paths;
   - account: `aws sts get-caller-identity --profile acme-readonly`, plus one read call the tasks need;
3. checks every tool the tasks name (`command -v rg jq aws`) and that the launch flags exist in `claude --help`.

## Worker environment (example)

```markdown
## Worker environment

- You audit; you change nothing. Your working directory is `/srv/acme`. Read `/srv/acme/api` freely; never write there.
- You write only `<report-dir>/T-0NN.md` and `<report-dir>/evidence/T-0NN/` (the real paths are in your package).
- AWS: use `--profile acme-readonly` only, with read calls (`describe-*`, `list-*`, `get-*`). The profile is already configured; you never see or print keys.
- Network: GET requests to `https://staging.acme.example` only. No other hosts.
- Never touch: other repos, `.env` files, other workers' reports, `SCRATCHPAD.md`, dependency manifests. Read under `deliverables/` only when your task's Sources name it; never write there.
- Secrets you meet: report the file and the type, never the value.
```

## Self-review (findings)

- Every findings task lists `Findings format` and `Severity scale`, and its Verify checks the ID prefix, the cells and the evidence files.
- Scopes within a wave do not overlap: no module, account or area is in two findings tasks of the same wave.
- There is a consolidation task (kind `document`, last wave); the cross-cutting review comes after it, then the reserved fix tasks.
- The deliverable decision (path, format, committed or not) exists and is `to confirm` until the user answers.
- Mixed plans reserve the fix slots (`### Tasks T-0NN … T-0MM: Reserved for fixes from T-0XX`).
- T-000 records a baseline per source, and the Worker environment names credentials only by variable or profile.

## Common mistakes (findings)

| Mistake | Fix |
|---|---|
| A finding without evidence ("auth looks weak") | The Evidence cell is mandatory; the Verify step fails on an empty cell |
| An "audit" task that edits code or fixes what it finds | Read-only; fixes are separate `code` tasks written after the wave |
| Two workers auditing the same module | Disjoint scopes within a wave, or one task |
| Scope check against a clean tree in the repo that holds the plan | Compare with the baseline recorded in T-000 |
| Severity left to each worker's taste | `Severity scale` contract in every findings task |
