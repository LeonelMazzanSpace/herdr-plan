# Findings tasks

Read this when the plan has findings tasks (audits, QA passes, reviews of something that already exists). The core steps are in `SKILL.md`; this file holds what only findings tasks need. A findings worker reads the sources and writes only its report and evidence: no worktree, no branch, no commits.

## Scope and access confirmation

Preflight step 4 for findings tasks.

   - **Read:** the plan (Sources and tools header, `## Decisions recorded for this plan`, T-000, Worker environment, the contract sections, each findings task's Scope and Sources) and the vault notes the tasks name. Touch no source and no account.
   - **Table**, in the user's language, one row per category: `Category · Value · Source · Status`.
     - Categories: sources (repos, accounts, URLs); access mode and credentials (by profile or variable name, never the value); production or real accounts; worker network access (hosts); findings format and severity scale; control list; deliverable (path, format, commit decision); out of scope.
     - Source: `plan`, `user`, `company default`.
     - Status: `confirmed` (the plan states it and nothing contradicts it), `conflict` (two sources disagree), `undecided` (a task needs it and nobody decided it, e.g. production access still `to confirm`).
   - **Also list** what may have been missed: a source a task reads that no row covers, scopes that overlap within a wave, a task with no severity scale, and the worker tool allowlist you propose (read tools, the read-only commands the plan names, Write/Edit only under `<report-dir>`) for the user to approve.
   - **Ask once**, with the same rule as the stack confirmation: show the table, then only the `conflict` and `undecided` rows, each with your recommendation and a one-line tradeoff, in the same message as the other preflight questions. Never approve a row for the user, and never widen access on their behalf.
   - **After the answer:** record each choice as a D-number `approved` and write a "Scope confirmed" line with the date in the scratchpad. If an answer changes the plan, revise it first (Sources and tools, T-000, Worker environment, the tasks it touches), re-run the plan's self-review and send `plan revised` to `clickup`.
   - **Resume:** skip only when the scratchpad shows "Scope confirmed" and the plan's Sources and tools, Worker environment, T-000 and deliverable decision are unchanged since that date.

## T-000 for this kind

Preflight step 10, done by you:

   1. Create `<report-dir>/parts` and `<report-dir>/evidence`, and the deliverable folder as the deliverable decision says (`deliverables/<run-id>/parts` and `evidence` in the coordination root, or the same layout at the outside path).
   2. Prove read-only access to every source with the commands the plan names (`aws sts get-caller-identity --profile <ro-profile>`, `test -r <path>`, `git -C <repo> status`).
   3. Record the sources baseline for each source repo: `git -C <repo> status --porcelain > <report-dir>/baseline-<repo>.status` and `git -C <repo> rev-parse HEAD > <report-dir>/baseline-<repo>.head`. The scope check compares against it later, excluding the paths you write yourself (`deliverables/`, the plan, `SCRATCHPAD.md`, any other path you write), never against "empty". Also record each findings task's Scope paths the same way (`git -C <repo> status --porcelain -- <scope paths> > <report-dir>/baseline-<TASK>.status`): the worker's Verify compares only those. Note it in the scratchpad ("Deliverable: ...; sources baseline").
   4. Check the tools the tasks name (`command -v rg jq aws`) and the launch flags in `claude --help`.

## Preparing a findings task

   - no worktree and no branch: the pane's `--cwd` is the coordination root, with no `--env`;
   - create `<report-dir>/evidence/<TASK>/`;
   - write `<report-dir>/<TASK>.vault.md` if the task lists vault notes: reread the notes through the MCP and quote the lines the task needs;
   - build the package with `make-package.sh` and no `--worktree`, `--branch`, `--base` or `--coord-branch` (the script rejects them for this kind); launch with the non-code mode of Preflight step 7.

## Accepting a findings task

   2. **Scope.** All three must hold:
      - the sources are intact against the T-000 baseline:
        ```bash
        EXCL='^(.. )?"?(deliverables/|SCRATCHPAD\.md|<plan path>|<other paths you write>)'
        git -C <repo> status --porcelain | grep -vE "$EXCL" | diff - <(grep -vE "$EXCL" <report-dir>/baseline-<repo>.status)
        git -C <repo> diff --name-only "$(cat <report-dir>/baseline-<repo>.head)" HEAD | grep -vE "$EXCL"
        ```
        `EXCL` lists every path you write yourself: `deliverables/`, `SCRATCHPAD.md`, the plan, and any other path you, the orchestrator, write (daily log, `.superpowers/`, …). Both print nothing. For an account or URL, which `git` cannot see, read the commands in the report and reject any that is not a read;
      - the worker wrote only under `<report-dir>`: `find <report-dir> -type f -newer <report-dir>/<TASK>.package.md` shows only `<TASK>.md`, `evidence/<TASK>/…` and other tasks' own files;
      - the report and the evidence hold no secret, token, password or hash: grep them.
   3. **Verify.** Re-run the task's Verify commands; they are green. Then open the evidence of **every Critical finding yourself** (the file:line, the saved output, the capture) and check that it shows what the finding says. A worker's "reproduced twice" is a claim.
   4. **Review**, as in `SKILL.md`: `bash <skill-dir>/scripts/make-review-package.sh --task T-0NN --model M --run-id R --reports D --kind findings [--notes F] [--attempt N]`. The reviewer's cwd is the coordination root, with the same non-code launch mode, and it re-checks every Critical and Important finding plus max(3, ceil(20% of Minor)) Minor, or all Minor when there are fewer than 3. After the review, run the sources check above again. Model: `opus` for production or real accounts.
   - **Verdicts.** `CHANGES_REQUIRED` when findings lack evidence fields, areas of the task's scope are uncovered, or a Critical/Important finding is `inaccurate`. A `not reproduced` finding alone is not a reason for a fix round: you move it at integration.

## Fix rounds

`CHANGES_REQUIRED` goes through `fix-round-template.md` like a code task: to the same worker session if it is alive, otherwise to a fresh `t0NN-f<N>`. Differences:
   - the cwd is the coordination root, read-only on the sources, not a worktree: replace the template's worktree line (`You are … in its existing worktree <path> …`) with the coordination-root cwd, its commit lines (`Add new commits on top: …` and `the commit(s) and files changed;`) with "no commits", and its test-DB line (`Verify (the test DB env var is already exported): …`) with `Verify:` and the task's Verify commands; replace its TDD bullet (`Fix every Critical and Important finding. TDD: …`) with "re-verify each finding, correct its evidence, cover the missing areas";
   - the worker rewrites `<report-dir>/<TASK>.md` and its evidence and adds an "Attempt N (fix round)" section saying what changed per finding;
   - scoped re-review with the next attempt number (`--attempt 2`, …); same escalation rule as code (a second failure on the same finding goes one model tier up).

## Integrating a findings task

Core Accepting step 6. After `APPROVED`. The cross-cutting review's report is the exception: it stays in `<report-dir>`, is never copied to `parts/`, and is not an audit part; its confirmed findings become fix tasks or debt, and you summarize it to the user at closing. For every other findings task:

   1. **Apply the verdicts** to the copy you are about to publish, never to the worker's report in `<report-dir>`: each `not reproduced` finding moves to a "Corrected false positives" section with the reviewer's observation, and is never deleted; each `inaccurate` Minor finding gets the reviewer's severity or description.
   2. **Copy** the corrected report to `deliverables/<run-id>/parts/<TASK>.md` and the evidence to `deliverables/<run-id>/evidence/<TASK>/` (add `evidence/<TASK>-review/` when a false positive cites it). Evidence links stay as the worker wrote them (`evidence/<TASK>/F01.txt`): they are relative to `deliverables/<run-id>/`, not to `parts/`.
   3. **Run the plan's gate** over `deliverables/<run-id>/parts/`. Green: `integrated`, then `verified`; close the task's panes. Committing follows the deliverable decision, at Closing.
   4. The consolidation reads only `deliverables/<run-id>/parts/`.

## Failures (findings)

| Situation | Action |
|---|---|
| Source access denied, credentials expired, or the worker needs a host or account outside the confirmed list | `BLOCKED`. Tell the user. Never widen access, change a profile or grant a role yourself. |
| A worker edited a source | Do not accept and stop its dependents. Report the diff to the user and discard nothing. |
| The sources differ from the baseline and the worker did not cause it (the repo moved) | Record it, re-record the baseline as a D-number, and check the tasks in flight. |
| A secret appears in a report or evidence | Do not copy it to `deliverables/`. Send a fix round: keep the file and the type, drop the value. |

## Closing (findings)

   - Order for a plan without code: consolidation task, deliverable (core step 2b), cross-cutting review as a `findings` task over the deliverable, reserved fix tasks, final gate. A mixed plan has two review tasks: the code review of the integrated branch and a `findings` task over the deliverable.
   - Before handing over: run the plan's gate once more, check the sources baseline a last time, confirm every `not reproduced` finding is listed in "Corrected false positives", and that finding IDs are unique and evidence links resolve from `deliverables/<run-id>/`.
   - Critical and Important findings of the cross-cutting review become fix tasks, as in core step 1. Its report stays in `<report-dir>` (not in `parts/`, so re-consolidation never reads it); summarize it to the user at closing.

## Red flags (findings)

| Thought | Reality |
|---|---|
| "The finding is obvious, no evidence needed" | No evidence, no finding: file:line, command and output, URL or capture |
| "I'll fix it while auditing" | Findings workers are read-only; fixes are separate `code` tasks |
| "The reviewer could not reproduce it, delete it" | It moves to Corrected false positives |
| "The report says PASS, the sources are fine" | Compare with the T-000 baseline yourself |
| "The worker needs production, I'll give it" | Access beyond the confirmation is the user's decision |
