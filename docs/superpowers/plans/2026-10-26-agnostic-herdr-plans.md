# Kind-Agnostic Herdr Plans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `writing-herdr-plans` / `executing-herdr-plans` (and their `-hermes` variants) run plans whose tasks are code, findings (audits) or documents, with the current code know-how kept word for word.

**Architecture:** Every task header gets a `**Kind:**` field (`code` | `findings` | `document`, missing = `code`). Each `SKILL.md` keeps the shared core; what differs per kind lives in `kinds/<kind>.md` next to it, loaded only when the plan has that kind. The code text is moved there verbatim, which a check script proves. `make-package.sh` and `make-review-package.sh` learn `--kind`, and for code they produce byte-identical packages, which tests prove against the pre-change scripts in git.

**Tech Stack:** Markdown skill files; bash scripts compatible with macOS bash 3.2 (`set -euo pipefail`, awk, grep, sed); no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-26-agnostic-herdr-plans-design.md` (Spanish; approved 2026-10-26)

**Repos and branches:** `herdr-plan` (baseline commit `759fd7a`) and `herdr-plan-hermes` (baseline commit `dceed87`), both under `/run/media/leonel/4f37aba0-a422-4ae0-b330-35fcb650f362/trabajo/skills/`. Work on `feature/agnostic-kinds` in each repo. No push.

## Global Constraints

- Kinds are exactly `code`, `findings`, `document`. The header field is `**Kind:** <kind>`, first field of the task header line. Missing field = `code`. Value is trimmed and lowercased before use; anything else is an error naming the task and the value.
- A plan without `Kind` fields produces packages and review packages byte-identical to the baseline scripts (`759fd7a` / `dceed87`) given the same arguments.
- Code know-how moves verbatim: every non-blank line of the baseline `writing-herdr-plans/SKILL.md` and `executing-herdr-plans/SKILL.md` appears unchanged in the new `SKILL.md` or in `kinds/code.md`, except the lines listed in that file's allowlist under `tests/allowed-changes/`. An allowlist line is only a line this plan tells you to change.
- Finding IDs: `<TASK>-F<NN>`, e.g. `T-003-F01`.
- Worker outputs for non-code tasks: report `<report-dir>/<TASK>.md` (as today), document part `<report-dir>/parts/<TASK>.md`, evidence `<report-dir>/evidence/<TASK>/`; reviewer evidence `<report-dir>/evidence/<TASK>-review/`.
- Deliverable decision (`to confirm` per plan): default `<COORDINATION_ROOT>/deliverables/<run-id>/` with `parts/`, `evidence/`, `<name>.md` and optional `<name>.html`, committed by the orchestrator on the coordination branch; alternative for sensitive evidence: the same layout outside the repo, not committed.
- `.md` is the deliverable's source; `.html` is generated from it as one file with inline CSS and no network loads, never hand-edited. Check: `grep -Eic '<script|<link[^>]*href="https?:|src="https?:' <file>` prints `0`.
- Reviewer sample of Minor findings: every Critical and Important, plus max(3, ceil(20% of Minor)) Minor, or all Minor when there are fewer than 3.
- Non-code workers launch with `--permission-mode dontAsk --allowedTools "<read tools, read-only commands the plan names, Write/Edit only under <report-dir>>"`, verified against `claude --help` at preflight.
- Skill names, the Telegram text of the `-hermes` variants and `herdr-qa-plan` / `herdr-execution` do not change.
- Skill files and READMEs stay in English.

## Review Focus

1. A plan written before this change (no `Kind` anywhere) must run exactly as before: same packages, same preflight, same acceptance. Pinned by the byte-identical tests in Tasks 1 and 2 and the verbatim checks in Tasks 3 and 5.
2. A `Kind` written with odd case or spacing (`**Kind:**  Findings `) must be read as `findings`, and an unknown value (`**Kind:** audit`) must stop with a message, not silently become `code`. Pinned in Task 1.
3. A `--kind` flag that disagrees with the task header must stop the script, so a package never contradicts its plan. Pinned in Task 1.
4. A non-code task given `--worktree`/`--branch` (copy-pasted code recipe) must stop with a message, not produce a package that tells a read-only worker about a branch. Pinned in Task 1.
5. A findings task that lists vault notes without `--vault-excerpts` must fail as it does for code today. Pinned in Task 1.

---

## File Structure

`herdr-plan/` (Task 8 mirrors it into `herdr-plan-hermes/` with the `-hermes` names):

| File | Change | Responsibility |
|---|---|---|
| `executing-herdr-plans/scripts/make-package.sh` | Modify | `--kind`; non-code packages; code output unchanged |
| `executing-herdr-plans/scripts/make-review-package.sh` | Modify | `--kind`; findings and document review checklists; code output unchanged |
| `tests/run.sh` | Create | Runs every test below; exit 1 on any failure |
| `tests/fixtures/plan.md` | Create | Minimal plan with the fixed headings and tasks T-001…T-006 |
| `tests/test-make-package.sh` | Create | Package tests (Task 1) |
| `tests/test-make-review-package.sh` | Create | Review package tests (Task 2) |
| `tests/check-moved-text.sh` | Create | Verbatim check (Task 3) |
| `tests/allowed-changes/writing-SKILL.txt`, `executing-SKILL.txt` | Create | Lines the plan allows to change |
| `writing-herdr-plans/SKILL.md` | Modify | Shared core + Kind field + pointer table |
| `writing-herdr-plans/kinds/code.md` | Create | Moved code rules |
| `writing-herdr-plans/kinds/findings.md`, `kinds/document.md` | Create | Task template, contract types, self-review per kind |
| `writing-herdr-plans/orchestration-section-template.md` | Modify | Kind column, non-code launch, deliverable block, non-code gate |
| `executing-herdr-plans/SKILL.md` | Modify | Shared core + pointers |
| `executing-herdr-plans/kinds/code.md` | Create | Moved stack confirmation, preparation, acceptance, merge and gate |
| `executing-herdr-plans/kinds/findings.md`, `kinds/document.md` | Create | Scope-and-access confirmation, preparation, acceptance, integration, gate, failures |
| `executing-herdr-plans/scratchpad-template.md`, `handoff-template.md` | Modify | Kind column, deliverable state |
| `README.md` | Modify | Kinds and deliverable |

---

### Task 1: `make-package.sh --kind`

**Files:**
- Modify: `executing-herdr-plans/scripts/make-package.sh`
- Create: `tests/run.sh`, `tests/fixtures/plan.md`, `tests/test-make-package.sh`

**Interfaces:**
- Produces: `make-package.sh … [--kind code|findings|document]`. For `findings`/`document` the required arguments are `--plan --task --model --why --run-id --reports --coord`; `--worktree --branch --base --coord-branch` are rejected with `make-package: --<arg> is only for code tasks`. Output path and printed line are as today.
- Produces: `tests/fixtures/plan.md`, used by Tasks 2 and 9. Sections: `## Decisions recorded for this plan`, `## Global Constraints`, `## Review Focus`, `## Worker environment`, `## Data contract`, `## Findings format`, `## Severity scale`, `## Document outline`, `## Sources`, `## Tasks` with:
  - `T-001` no `Kind`, Contracts `Data contract`;
  - `T-002` `**Kind:** findings`, Contracts `Findings format, Severity scale`;
  - `T-003` `**Kind:** document`, Contracts `Document outline, Sources`;
  - `T-004` `**Kind:**  Findings ` (odd spacing and case);
  - `T-005` `**Kind:** audit` (invalid);
  - `T-006` `**Kind:** findings` with `**Vault:** concepts/Pedido`.
- Produces: `tests/run.sh` runs `tests/test-*.sh` and `tests/check-*` invocations listed in it, prints `ok <name>` / `FAIL <name>`, exits 1 on any FAIL.

- [ ] **Step 1: Write the fixture plan and the failing tests** in `tests/test-make-package.sh`. Each test runs the script into a temp report dir (`mktemp -d`) and asserts:
  - `code_identical_to_baseline`: for T-001, the output of `git show 759fd7a:executing-herdr-plans/scripts/make-package.sh` and of the current script, run with the same full code arguments, are byte-identical (`cmp`).
  - `explicit_code_kind_identical`: same as above with `--kind code`.
  - `findings_package`: T-002 with only the non-code arguments succeeds. The package contains `findings_worker (read-only on sources`, `T-002-F`, `evidence/T-002/`, the `## Findings format` and `## Severity scale` sections, and does not contain `branch` or `merge-base`.
  - `document_package`: T-003 succeeds. The package contains `document_worker`, `parts/T-003.md`, `## Document outline`, and does not contain `merge-base`.
  - `kind_normalized`: T-004 builds as findings (contains `findings_worker`).
  - `kind_invalid`: T-005 exits 1 and stderr contains `invalid Kind 'audit' in T-005`.
  - `kind_flag_conflict`: T-002 with `--kind document` exits 1 and stderr contains `--kind document contradicts Kind findings in T-002`.
  - `worktree_rejected_for_findings`: T-002 with `--worktree /x` exits 1 and stderr contains `--worktree is only for code tasks`.
  - `vault_required_for_findings`: T-006 without `--vault-excerpts` exits 1 and stderr contains `pass --vault-excerpts`.

- [ ] **Step 2: Run `bash tests/run.sh`.** Expected: `code_identical_to_baseline` ok; the other tests FAIL.

- [ ] **Step 3: Implement `--kind` in `make-package.sh`.**
  - Parse `--kind`. Read `header_field Kind` from the task; normalize it by trimming and lowercasing; empty means `code`. Validate the result.
  - Conflict rule: a flag and a header that both exist and differ is an error.
  - Required arguments depend on the kind. Code: today's list. Non-code: the list above, and the four code-only arguments are rejected if given.
  - Keep the code branch's heredocs character for character. Add `findings` and `document` branches. Each sets the role line, objective, git line, allowed-writes line, location line and output line from the spec, section 2:
    - **findings:** read-only on sources; IDs `$TASK-F<NN>`; evidence under `$REPORTS/evidence/$TASK/`; the report lists the scope covered and not covered, commands with observed results, and findings in the `Findings format` contract.
    - **document:** write the part to `$REPORTS/parts/$TASK.md` following `Document outline`; cite a `Sources` entry for every claim; the report lists the sources consulted and open questions.
  - The location line for non-code is `Working directory and sources (read-only): \`$COORD\` and the sources your task and Worker environment list.`

- [ ] **Step 4: Run `bash tests/run.sh`.** Expected: every `test-make-package` test ok.

- [ ] **Step 5: Commit**
```bash
git add executing-herdr-plans/scripts/make-package.sh tests/run.sh tests/fixtures/plan.md tests/test-make-package.sh
git commit -m "feat: package findings and document tasks in make-package.sh"
```

### Task 2: `make-review-package.sh --kind`

**Files:**
- Modify: `executing-herdr-plans/scripts/make-review-package.sh`
- Create: `tests/test-make-review-package.sh` (and add it to `tests/run.sh`)

**Interfaces:**
- Consumes: the fixture plan and the packages from Task 1. Each test first builds the task package with `make-package.sh` and writes a stub implementer report `<report-dir>/<TASK>.md`.
- Produces: `make-review-package.sh … [--kind code|findings|document] [--integrated <dir>]`.
  - Code requires today's arguments.
  - Non-code requires `--task --model --run-id --reports` and rejects `--worktree --branch --base`.
  - `--integrated` is for `document` only. It is the dir of parts already integrated; when it is given, the reviewer compares the part against them.

- [ ] **Step 1: Write the failing tests:**
  - `review_code_identical_to_baseline`: the baseline `759fd7a` script and the current one, with the same code arguments, produce byte-identical files.
  - `review_findings`: the package contains `confirmed`, `not reproduced`, `inaccurate`, `max(3`, `evidence/T-002-review/`, `CHANGES_REQUIRED`, and does not contain `git -C`.
  - `review_document`: with `--integrated <dir>`, the package contains `parts/T-003.md`, that dir's path, `without a source`, `contradict`.
  - `review_integrated_only_for_document`: `--integrated` with findings exits 1.

- [ ] **Step 2: Run `bash tests/run.sh`.** Expected: the baseline test ok, the new ones FAIL.

- [ ] **Step 3: Implement.** The code branch keeps today's heredoc character for character. The findings and document checklists, verdict rules and sample rule are the spec's section 2 text, under **Veredicto del revisor**:
  - **findings:** re-check each finding in the sample. Per finding: `ID · verdict (confirmed | not reproduced | inaccurate) · how it was re-checked`.
  - **findings, `CHANGES_REQUIRED` when:** a finding lacks evidence fields; an area of the task's scope was not covered; or a Critical/Important finding is inaccurate.
  - **document, `CHANGES_REQUIRED` when:** a Critical/Important claim has no source; the part contradicts an integrated part; or a section of the outline is missing.

- [ ] **Step 4: Run `bash tests/run.sh`.** Expected: all ok.

- [ ] **Step 5: Commit** (`feat: review packages for findings and document tasks`), staging the script, the test and `tests/run.sh`.

### Task 3: writing-herdr-plans core and `kinds/code.md`

**Files:**
- Create: `tests/check-moved-text.sh`, `tests/allowed-changes/writing-SKILL.txt`, `writing-herdr-plans/kinds/code.md`
- Modify: `writing-herdr-plans/SKILL.md`, `tests/run.sh`

**Interfaces:**
- Produces: `bash tests/check-moved-text.sh --old <rev>:<path> --allow <file> <new-file>...`.
  - Checks each non-blank line of the old file with `grep -Fxq` against the new files and the allowlist.
  - Prints `missing: <line>` for each line found in none of them and exits 1 if there is any.
  - Task 5 reuses it.
- Produces: `writing-herdr-plans/kinds/code.md` with headings `# Code tasks`, `## Task steps`, `## Rules for parallel code workers`, `## E2E, usability and motion task`, `## Self-review (code)`, `## Common mistakes (code)`. Task 4 links to these headings.

- [ ] **Step 1: Write the check script.** Add `check-moved-text writing` to `tests/run.sh`:
```bash
bash tests/check-moved-text.sh --old 759fd7a:writing-herdr-plans/SKILL.md --allow tests/allowed-changes/writing-SKILL.txt writing-herdr-plans/SKILL.md writing-herdr-plans/kinds/code.md
```
  Also add a test that a line removed from a copy of the old file is reported. That is the script's own failing test.

- [ ] **Step 2: Run `bash tests/run.sh`.** Expected: the self-test ok. `check-moved-text writing` passes trivially, because nothing has moved yet.

- [ ] **Step 3: Move the code-only text to `kinds/code.md`, verbatim.** Line numbers refer to `759fd7a`:
  - "T-000 belongs to the orchestrator" (L92) → `## Rules for parallel code workers`.
  - "Disjoint files within a wave" (L98) and "Test isolation per worker" (L99) → `## Rules for parallel code workers`.
  - The E2E, usability and motion task (L120–126) → `## E2E, usability and motion task`.
  - "The rest of the task follows the writing-plans task template…" (L84) → `## Task steps`.
  - Self-review items 2, 3 and 8 → `## Self-review (code)`.
  - Common-mistakes rows → `## Common mistakes (code)`: "A new branch per attempt", "Dependencies added by whichever task first needs them", "E2E step that only clicks…", "Animation rules left to each UI worker's taste". Keep the table header row in both files.

- [ ] **Step 4: Edit the shared core of `SKILL.md`.** Put every replaced old line into `tests/allowed-changes/writing-SKILL.txt`:
  - frontmatter `description`: "Use when writing a plan — code, an audit, research, documentation, a proposal or a migration plan — from an approved spec that will be executed by an orchestrator Claude session delegating tasks to independent Claude Code workers in Herdr panes";
  - Overview first sentence, `REQUIRED SUB-SKILL` line ("TDD task steps for code tasks"), the announce line ("orchestrated plan");
  - When to Use: add audits, research, documentation, proposals and migration plans;
  - Before Writing step 7 gets one bullet: for findings and document tasks, these change scope:
    - access to production or real accounts;
    - credentials, by name only;
    - worker network access;
    - the deliverable's audience and location (the decision in Global Constraints);
  - Plan Document Structure table:
    - Header row: `Tech Stack` for code tasks and/or `Sources and tools` for findings and document tasks;
    - Contract sections row: also `## Findings format`, `## Severity scale`, `## Control list`, `## Document outline`, `## Style guide`, `## Sources`, `## Comparison criteria`;
  - Task header line example: starts with `**Kind:** code · `, plus one line: "`Kind` is `code`, `findings` or `document`; a task without it is `code`";
  - After the T-000 bullet (L87), one line: "What T-000 contains depends on the kinds in the plan: see each kind file";
  - A new `## What changes per kind` section before `## Rules That Make Parallel Workers Possible`: a table `Kind · What the worker delivers · Read when the plan has it` with rows `code → kinds/code.md`, `findings → kinds/findings.md`, `document → kinds/document.md`, plus "A plan reads only the kind files of the kinds it uses";
  - Rules: "Permission mode is an execution decision" (L93) gets one sentence on `dontAsk` with the allowlist for findings and document workers; "Closing tasks" (L127) gets one sentence on the consolidation task, a `document` task in the last wave whenever the plan has findings or document tasks;
  - Model Per Task table gets one row: "Findings and document tasks against a fixed format · `sonnet`; security, compliance or architecture audits · `opus`";
  - Self-Review Additions gets item 9: "Every task has a valid `Kind` or none; run the self-review section of each kind file the plan uses".

- [ ] **Step 5: Run `bash tests/run.sh`.** Expected: all ok. A `missing:` line means text was lost: restore it, never add it to the allowlist.

- [ ] **Step 6: Commit** (`refactor: move code-only planning rules to kinds/code.md`).

### Task 4: writing-herdr-plans `kinds/findings.md`, `kinds/document.md` and the orchestration template

**Files:**
- Create: `writing-herdr-plans/kinds/findings.md`, `writing-herdr-plans/kinds/document.md`
- Modify: `writing-herdr-plans/orchestration-section-template.md`

**Interfaces:**
- Consumes: the headings of `kinds/code.md` (Task 3), and the package line texts of Task 1, so that the task steps match what the package asks for.
- Produces: each file has `## Task steps` (template), `## Contracts` (contract types with one filled example each), `## T-000 for this kind`, `## Self-review (<kind>)`, and `## Common mistakes (<kind>)`.

- [ ] **Step 1: Write `kinds/findings.md`:**
  - **Task template:** header line with `**Kind:** findings`; `**Scope:**` (what to examine, what not); `**Sources:**` (paths, accounts by profile name, URLs); numbered acceptance criteria; steps "survey", "verify each finding", "write in the Findings format", and **Verify** with concrete self-check commands, e.g. `grep -c '^| T-002-F' <report>` equals the number of findings and every row has a non-empty Evidence cell.
  - **Contracts:** `Findings format` as a table `ID · Severity · Title · Evidence (file:line, command + output, URL, screenshot path) · Impact · Recommendation`; `Severity scale` with Critical, Important, Minor and their criteria; `Control list` for compliance audits.
  - **T-000:** create `<report-dir>/parts` and `<report-dir>/evidence`; prove read-only access per source (`git -C <repo> status --porcelain` plus `git rev-parse HEAD` recorded as the baseline; `aws sts get-caller-identity --profile <read-only profile>`); check the tools the tasks name.
  - **Self-review:** every findings task lists `Findings format` and `Severity scale`; scopes within a wave do not overlap; there is a consolidation task; the deliverable decision exists and is `to confirm` until answered; mixed plans reserve the code fix slots (`### Tasks T-0NN … T-0MM: Reserved for fixes from T-0XX`).
  - **Worker environment** for this kind, as one filled example: the sources the worker may read, credentials by variable or profile name only, where it writes (`<report-dir>` only), whether it has network access, and what it must never touch.
  - **Common mistakes:** a finding without evidence; an "audit" that edits code; two workers auditing the same module.

- [ ] **Step 2: Write `kinds/document.md`.** It has the same shape with `**Kind:** document`:
  - **Task template:** `**Part:** <outline section>`; steps "read sources", "write the part", "cite", and **Verify** checking that every outline heading exists in `parts/T-0NN.md` (`grep -c '^## '`) and that claims carry `[S<n>]` source tags.
  - **Contracts:** `Document outline`, `Style guide`, `Sources` (numbered `S1…`) and `Comparison criteria` for research comparisons.
  - **Consolidation task:**
    - kind `document`, in the last wave;
    - reads `deliverables/<run-id>/parts/`, writes `<name>.md` with an executive summary, the parts, the confirmed findings, a corrected false positives section and the recommendation;
    - when the format is `html`, it also writes `<name>.html` from the `.md` under the Global Constraints rule, and its Verify runs the `grep` check.
  - **T-000** for this kind, its Worker environment example (as in `findings.md`, writing to `<report-dir>/parts/`), its self-review and its common mistakes.

- [ ] **Step 3: Edit `orchestration-section-template.md`:**
  - Model policy table gets a `Kind` column.
  - Roles: "worktrees and databases" becomes "worktrees and databases (code tasks); the deliverable (findings and document tasks)".
  - Add a `**Non-code worker launch**` block: `--cwd` set to the coordination root, `--permission-mode dontAsk --allowedTools "<verified allowlist>"`, `--add-dir "$report_dir"`, and the same prompt line.
  - Add a `**Deliverable**` block with path, format and commit decision `D<n>` `to confirm`.
  - Acceptance per task: one line each, "code: as above; findings and document: `kinds/<kind>.md` in executing-herdr-plans".
  - Integration gate: one line, "findings and document: the plan's check commands over `deliverables/<run-id>/parts/` (unique IDs, filled evidence fields, outline headings present)".

- [ ] **Step 4: Verify.** `grep -c '\*\*Kind:\*\*' writing-herdr-plans/kinds/*.md` shows at least 1 per file. `bash tests/run.sh` is all ok.

- [ ] **Step 5: Commit** (`feat: planning rules for findings and document tasks`).

### Task 5: executing-herdr-plans core and `kinds/code.md`

**Files:**
- Create: `executing-herdr-plans/kinds/code.md`, `tests/allowed-changes/executing-SKILL.txt`
- Modify: `executing-herdr-plans/SKILL.md`, `tests/run.sh`

**Interfaces:**
- Produces: `executing-herdr-plans/kinds/code.md` with `## Stack confirmation`, `## Preparing a code task`, `## Accepting a code task`, `## Integrating a code task`, `## Failures (code)`, `## Closing (code)` and `## Red flags (code)`. Task 6 mirrors these headings for the other kinds.

- [ ] **Step 1: Add the verbatim check** for the executing skill to `tests/run.sh`, then run it. Expected: ok, because nothing has moved yet.

- [ ] **Step 2: Move the code text verbatim to `kinds/code.md`.** Line numbers refer to `759fd7a`:

  | Lines | Content | Destination |
  |---|---|---|
  | 54–72 | Preflight step 4 body | `## Stack confirmation` |
  | 99–103 | Wave Loop step 1 body | `## Preparing a code task` |
  | 89 | The `Model order … E2E_DATABASE_NAME` line | `## Preparing a code task` |
  | 164–165 | Accepting steps 2–3 | `## Accepting a code task` |
  | 179–181 | Accepting step 6 (merge and full gate) | `## Integrating a code task` |
  | 187, 197–199 | Failure rows: BLOCKED by something you own; integration gate red and its two sub-rows | `## Failures (code)`, with the table header |
  | 225–226 | Closing step 2 bullets (UI final verification); line 224, "Run the final gate…", stays in the core | `## Closing (code)` |
  | — | Red Flags rows "The plan says TypeORM…" and "The user is in a hurry, skip the stack table" | `## Red flags (code)` |

- [ ] **Step 3: Edit the shared core of `SKILL.md`,** listing every replaced line in the allowlist:
  - **Frontmatter and overview:**
    - `description`: "Use when executing an approved plan (code, audit, research, documents) by orchestrating independent Claude Code workers in Herdr panes, or when resuming, checking status of, closing such a run, or taking it over as a relief orchestrator";
    - Overview: each task goes to a fresh worker in its own pane (a git worktree for code tasks), is checked by an independent reviewer and integrated by the orchestrator behind a gate.
  - **Roles:**
    - the orchestrator bullet adds "the deliverable (findings and document tasks)".
  - **Preflight:**
    - step 4 keeps its title line and one paragraph: code tasks → `kinds/code.md § Stack confirmation`; findings/document → `kinds/<kind>.md § Scope and access confirmation`; a mixed plan shows both tables in one message. Urgency never skips it, and you never approve a row for the user;
    - step 6 builds the first task's package whatever its kind;
    - step 7 adds the non-code launch mode (Global Constraints);
    - step 10: "Do T-000 yourself as the kind files describe; record the base commit and, for findings and document tasks, the sources baseline".
  - **Wave Loop and acceptance:**
    - Wave Loop step 1: "Prepare each task as its kind file says";
    - Pane and launch steps: add one line saying that for non-code tasks `<wt>` is the coordination root, no `--env` is passed, and the launch uses the non-code mode;
    - Accepting: steps 1, 4 and 5 stay in place. Steps 2–3 become "Scope and verification: the kind file's Accepting section". Step 6 becomes "Integration: the kind file's Integrating section". Step 5 adds "for findings and document tasks, `CHANGES_REQUIRED` follows the kind file's rules";
    - ClickUp table note: for non-code tasks, `integrated` means the part was copied into `deliverables/<run-id>/parts/`, and `verified` means the plan's gate is green over the parts.
  - **Closing:**
    - step 1 reviews the integrated branch or the deliverable;
    - step 2 keeps "Run the final gate", plus "UI plans: `kinds/code.md § Closing (code)`";
    - new step 2b: consolidation task accepted → generate the deliverable, commit it as decided, give the user its absolute path.
  - **Quick Reference:**
    - the package rows show `[--kind K]` and `--integrated`.

- [ ] **Step 4: Run `bash tests/run.sh`.** Expected: all ok, with no `missing:` lines.

- [ ] **Step 5: Commit** (`refactor: move code-only execution steps to kinds/code.md`).

### Task 6: executing-herdr-plans `kinds/findings.md`, `kinds/document.md`, scratchpad and hand-off templates

**Files:**
- Create: `executing-herdr-plans/kinds/findings.md`, `executing-herdr-plans/kinds/document.md`
- Modify: `executing-herdr-plans/scratchpad-template.md`, `executing-herdr-plans/handoff-template.md`

**Interfaces:**
- Consumes: the headings of Task 5, the script flags of Tasks 1–2, and the paths in Global Constraints.

- [ ] **Step 1: Write `kinds/findings.md`:**
  - **Scope and access confirmation:** a table `Category · Value · Source · Status` with the rows sources, access mode and credentials by name, production or real accounts, worker network access, findings format and severity scale, control list, deliverable (path, format, commit), and out of scope. It uses the same statuses and "ask once" rule as the stack confirmation.
  - **Preparing:** no worktree. Create `<report-dir>/evidence/<TASK>/`. Write `<TASK>.vault.md` if needed.
  - **Accepting:**
    - the report is PASS;
    - sources are intact against the T-000 baseline;
    - the worker wrote only under `<report-dir>`;
    - you open the evidence of every Critical finding yourself;
    - then the review, by `make-review-package.sh --kind findings`.
  - **Integrating:**
    - not-reproduced findings move to the corrected false positives list;
    - the report and its evidence are copied to `deliverables/<run-id>/parts/<TASK>.md` and `evidence/<TASK>/`;
    - the plan's gate runs.
  - **Failures (findings):** source access denied or credentials expired → BLOCKED, tell the user, never widen access yourself. A worker that edited a source → do not accept, report the diff and discard nothing.
  - **Red flags:** "The finding is obvious, no evidence needed"; "I'll fix it while auditing".

- [ ] **Step 2: Write `kinds/document.md`** with the same headings:
  - **Scope confirmation rows:** sources, audience, deliverable, style guide, outline.
  - **Accepting:** check the part against the outline. The review uses `--kind document --integrated deliverables/<run-id>/parts`.
  - **Integrating:** copy the part.
  - **Consolidation and rendering:** the html check from Global Constraints. Never hand-edit the html.

- [ ] **Step 3: Edit the templates:**
  - `scratchpad-template.md`: the tasks table gets a `Kind` column. "References and environment" gets `<Deliverable: path, format, commit decision D<n>; sources baseline>`.
  - `handoff-template.md`: the entry gets `Deliverable: <parts integrated / missing, consolidation state | not applicable>` after `Safe point`.

- [ ] **Step 4: Verify.** Every `kinds/code.md` heading has a counterpart in both new files: `grep '^## ' executing-herdr-plans/kinds/*.md` shows the matching names. `bash tests/run.sh` is all ok.

- [ ] **Step 5: Commit** (`feat: execution steps for findings and document tasks`).

### Task 7: README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the README:**
  - The intro says the skills run code, audits, research, documentation, proposals and migration plans.
  - Add a "Kinds of task" section with the three-row table and the deliverable rule (md or html, where it lives).
  - The Flow step "Confirm the stack" becomes "Confirm the stack (code) or scope and access (other kinds)".
  - The file tree shows `kinds/` and `tests/`.

- [ ] **Step 2: Verify** that `grep -n 'kinds/' README.md` shows the tree lines, and that every path it names exists (`ls` each one).

- [ ] **Step 3: Commit** (`docs: explain task kinds in the README`).

### Task 8: Mirror into `herdr-plan-hermes`

**Files:**
- Create in `herdr-plan-hermes/`: `writing-herdr-plans-hermes/kinds/{code,findings,document}.md`, `executing-herdr-plans-hermes/kinds/{code,findings,document}.md`, `tests/` (same files, baseline commit `dceed87`)
- Modify in `herdr-plan-hermes/`: both `SKILL.md`, `orchestration-section-template.md`, both scripts, `scratchpad-template.md`, `handoff-template.md`, `README.md`

**Interfaces:**
- Consumes: the final files of Tasks 1–7.

- [ ] **Step 1: Copy the `kinds/` files and `tests/`.** Replace the skill names (`executing-herdr-plans` → `executing-herdr-plans-hermes`, `writing-herdr-plans` → `writing-herdr-plans-hermes`) and the baseline commit (`759fd7a` → `dceed87`).

- [ ] **Step 2: Apply to the hermes `SKILL.md` files and templates the same edits as Tasks 3–6.** Leave every Telegram line in place. The allowlists are the herdr-plan ones with the names replaced, plus nothing else. Add one line to the Telegram events table: the `done` row's text includes "the deliverable's absolute path, when the plan has one".

- [ ] **Step 3: Copy the two scripts and re-apply each one's comment-line difference** (`writing-herdr-plans-hermes` in `make-package.sh` line 2).

- [ ] **Step 4: Verify:**
  - `bash tests/run.sh` in `herdr-plan-hermes` is all ok.
  - `diff -r herdr-plan/writing-herdr-plans/kinds herdr-plan-hermes/writing-herdr-plans-hermes/kinds` shows only skill-name lines, and the same holds for executing.
  - `diff` of each `SKILL.md` pair shows only the differences that existed at the baselines (compare with `git diff --no-index` of the baseline pair).

- [ ] **Step 5: Update the hermes README the same way as Task 7, then commit in `herdr-plan-hermes`** (`feat: task kinds for code, findings and document plans`).

### Task 9: End-to-end check with a mixed plan

**Files:**
- Create: `tests/fixtures/mixed-plan.md`, `tests/test-mixed-plan.sh` (in both repos; add to `tests/run.sh`)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write a small mixed plan by following the new writing skill as an author would.** It is an audit of a repo:
  - T-000 is the orchestrator's;
  - T-001 and T-002 are `findings` with disjoint scopes;
  - T-003 is the consolidation `document` task;
  - `### Tasks T-004 … T-006: Reserved for fixes from T-001, T-002`;
  - a deliverable decision `to confirm`.

  The test asserts:
  - the plan passes the self-review greps from Tasks 3–4 (every task has a valid Kind; findings tasks list both contracts; a consolidation task exists);
  - packages build for T-001…T-003;
  - review packages build for T-001 and T-003.

- [ ] **Step 2: Run `bash tests/run.sh`** in both repos. Expected: all ok.

- [ ] **Step 3: Commit** in each repo (`test: mixed findings and document plan end to end`).
