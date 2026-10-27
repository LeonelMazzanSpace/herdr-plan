# Document tasks

Read this when the plan has document tasks (a section of a report, a comparative research, a migration plan, documentation, a proposal), including the consolidation task of any plan with findings. The core steps are in `SKILL.md`; this file holds what only document tasks need. A document worker reads its sources and writes only its part and its report: no worktree, no branch, no commits.

## Scope and access confirmation

Preflight step 4 for document tasks. Read-only (touch no source and no account). Show one table, in the user's language, one row per category: `Category · Value · Source · Status` (Source: `plan`, `user`, `company default`). Ask once: after the table, list only the `conflict` and `undecided` rows, each with your recommendation and a one-line tradeoff, in the same message as the other preflight questions. Never approve a row for the user, and never widen access on their behalf.

   - **Rows:** sources (files, URLs, repos, with the access each needs: network hosts, credentials by name); audience; deliverable (path, format `md` or `html`, commit decision); style guide; outline (sections, exact headings, owner task of each); out of scope. Also show the worker tool allowlist you propose, including a render command only if the plan names one as a decision, for the user to approve.
   - **Status:** `confirmed`, `conflict` (e.g. a task cites a source number the Sources contract lacks), `undecided` (audience or format not decided).
   - **After the answer:** D-numbers `approved`, a "Scope confirmed" line with the date in the scratchpad, plan revised first if an answer changes it. **Resume:** skip only when that line exists and the Sources, outline, style guide and deliverable decision are unchanged.

## T-000 for this kind

Preflight step 10, done by you:

   1. Create `<report-dir>/parts`, and the deliverable folder as the deliverable decision says (`deliverables/<run-id>/parts` in the coordination root, or the same layout at the outside path).
   2. Prove every source is readable (`test -r <file>`, `curl -sI -o /dev/null -w '%{http_code}\n' <url>`).
   3. Record the sources baseline for each repo source: `git -C <repo> status --porcelain > <report-dir>/baseline-<repo>.status` and `git -C <repo> rev-parse HEAD > <report-dir>/baseline-<repo>.head`. The scope check compares against it later, excluding the paths you write yourself (`deliverables/`, the plan, `SCRATCHPAD.md`), never against "empty". For a local file source that is not in a repo (PDF, export): `sha256sum <file> > <report-dir>/baseline-<name>.sha256` (`shasum -a 256` on macOS); URLs and remote documents are read-only by nature, so record nothing. Note "Deliverable: ...; sources baseline" in the scratchpad.
   4. Check the tools the tasks name (`command -v pdftotext`, the render command if the plan names one) and the launch flags in `claude --help`.

## Preparing a document task

   - no worktree: the pane's `--cwd` is the coordination root, with no `--env`;
   - `<report-dir>/parts/` already exists (T-000). Write `<report-dir>/<TASK>.vault.md` if the task lists vault notes;
   - build the package with `make-package.sh` and no `--worktree`, `--branch`, `--base` or `--coord-branch`; launch with the non-code mode of Preflight step 7.

## Accepting a document task

   2. **Scope.** The sources are intact against the T-000 baseline (the check in `kinds/findings.md § Accepting a findings task`, step 2: read that section even in a document-only plan; for a local file source, `sha256sum -c <report-dir>/baseline-<name>.sha256 > /dev/null` exits 0 when the file is intact; `shasum -a 256 -c` on macOS), and the worker wrote only `<report-dir>/<TASK>.md` and `<report-dir>/parts/<TASK>.md` (plus `<TASK>.html` for the consolidation when the format is html), checked with `find <report-dir> -type f -newer <report-dir>/<TASK>.package.md`. Then **check the part against the outline yourself**: the Document outline's exact headings for this task are all present and spelled the same, no heading of another task's section appears, and no source tag is outside the task's Sources or the "New sources" its report lists (check each is real and read-only). No secret, token, password or hash in the part.
   3. **Verify.** Re-run the task's Verify commands; they are green. Spot-check a few claims against the source they cite.
   4. **Review**, as in `SKILL.md`: from the **second part on**, pass the integrated parts:
      ```bash
      bash <skill-dir>/scripts/make-review-package.sh --task T-0NN --model M --run-id R --reports D --kind document --integrated deliverables/<run-id>/parts [--notes F] [--attempt N]
      ```
      Without `--integrated` the reviewer silently skips the contradiction check, so never omit it once `deliverables/<run-id>/parts/` holds a part (the first part has nothing to compare). The reviewer's cwd is the coordination root, with the same non-code launch mode.
   - **Verdicts.** `CHANGES_REQUIRED` when a Critical/Important claim has no source, the part contradicts an integrated part, or a section of the outline is missing. Minor findings stay as notes in the review file.

## Fix rounds

`CHANGES_REQUIRED` goes through `fix-round-template.md` like a code task: to the same worker session if it is alive, otherwise to a fresh `t0NN-f<N>`. Differences:
   - the cwd is the coordination root, read-only on the sources, not a worktree: replace the template's worktree line (`You are … in its existing worktree <path> …`) with the coordination-root cwd, its commit lines (`Add new commits on top: …` and `the commit(s) and files changed;`) with "no commits", and its test-DB line (`Verify (the test DB env var is already exported): …`) with `Verify:` and the task's Verify commands; replace its TDD bullet (`Fix every Critical and Important finding. TDD: …`) with "add the missing citations, remove or mark `Note:` what no source supports, resolve the contradiction as the orchestrator rules";
   - the worker rewrites `<report-dir>/parts/<TASK>.md` and adds an "Attempt N (fix round)" section to its report;
   - scoped re-review with the next attempt number, again with `--integrated`; same escalation rule as code (a second failure on the same finding goes one model tier up).

## Integrating a document task

Core Accepting step 6. After `APPROVED`: copy `<report-dir>/parts/<TASK>.md` to `deliverables/<run-id>/parts/<TASK>.md`, then append each entry of the report's "New sources" to the plan's `## Sources` as a D-number (if two parts of a wave claim the same new number for different sources, send the later one a fix round to renumber), then run the plan's gate over `deliverables/<run-id>/parts/` (full outline, internal links, no missing parts). Green: `integrated`, then `verified`; close the task's panes. Committing follows the deliverable decision, at Closing.

## Consolidation and rendering

The consolidation task (kind `document`, in the last wave of findings and document work, before the cross-cutting review) is accepted and integrated like any part, with these additions:

   - It reads only `deliverables/<run-id>/parts/`. Start it only when every part and every findings part is `integrated`.
   - Accepting: no part's claim was changed (`grep -vxFf <report-dir>/parts/<consolidation TASK>.md deliverables/<run-id>/parts/<document TASK>.md` prints the lines of a document part the consolidation dropped or changed; run it for each document part, not for findings parts, which the consolidation reshapes into its fixed sections; differences in headings are expected), the contradictions between parts are listed in its report rather than silently resolved, and all the fixed sections of the variant the task states exist: both kinds of task, executive summary, every part in outline order, confirmed findings, Corrected false positives and recommendation; only findings tasks, executive summary, confirmed findings, Corrected false positives and recommendation; no findings tasks, executive summary, every part in outline order and recommendation.
   - **html.** When the format is `html`, the consolidation worker generates `<report-dir>/parts/<consolidation TASK>.html` itself from its `.md`, as one file with inline CSS and no network loads, and again whenever the `.md` changes. It uses an external render command only if the plan names one as a decision. You run `grep -Eic '<script|<link[^>]*href="https?:|src="https?:' <report-dir>/parts/<consolidation TASK>.html`; it must print `0`. Open the html yourself. **Never hand-edit the html**: a defect goes back to the worker as a fix round that corrects the `.md` and renders again.
   - Place the deliverable (`<name>.md`, and `.html`) as soon as the consolidation is integrated, before the cross-cutting review is dispatched (core step 2b), and place it again after any later fix. The commit and the path for the user are core Closing steps 2b and 7. Any later fix that changes a part or the consolidation means rendering again, and repeating the html check.

## Failures (document)

| Situation | Action |
|---|---|
| A source cannot be read (URL down, file moved, access denied) | `BLOCKED`. Tell the user. Never substitute another source or widen access yourself. |
| The worker needs a source or an outline heading that is not in the contracts | `BLOCKED` is correct. Contracts are yours: fix the plan on the coordination branch as a D-number, or tell the user if it changes scope. |
| A worker edited a source | Do not accept and stop its dependents. Report the diff to the user and discard nothing. |
| Two parts contradict each other | Do not integrate the later one until it is resolved: fix round on that part, or a user decision if it changes scope. Record it as a D-number. |
| The html fails the `grep` check or looks wrong | Fix round to the consolidation worker on the `.md`; render again. |

## Closing (document)

   - Order for a plan without code: consolidation task, deliverable (core step 2b), cross-cutting review as a `findings` task over the deliverable (coherence, contradictions, claims without a source), reserved fix tasks, final gate. A mixed plan has two review tasks: the code review of the integrated branch and a `findings` task over the deliverable.
   - Before handing over: the plan's gate over the final `<name>.md`, the html check when html, and the sources baseline once more.
   - Critical and Important findings of the cross-cutting review become fix tasks, as in core step 1. Its report stays in `<report-dir>`, not in `parts/`; summarize it to the user at closing.

## Red flags (document)

| Thought | Reality |
|---|---|
| "It reads well, the sources can wait" | A claim without a source is removed or marked `Note:` |
| "Skip `--integrated`, the part is independent" | Without it the contradiction check does not run |
| "One small tweak to the html" | The `.md` is the source: fix it and render again |
| "I'll resolve the contradiction while consolidating" | Contradictions are listed, then ruled by you or the user |
