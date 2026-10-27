# Document tasks

Read this when the plan has document tasks (a section of a report, a comparative research, a migration plan, documentation, a proposal), including the consolidation task of any plan with findings.

## Task steps

A document task replaces the TDD steps of writing-plans with the template below. The worker reads the sources and writes only its part and its report: no worktree, no branch, no commits. `<report-dir>` is known only at execution (the package gives the real path); everything else is written concretely.

````markdown
### Task T-004: Write the part "Operational cost"

**Kind:** document · **Model:** sonnet · **Depends on:** T-000 · **Parallel with:** T-005 · **Contracts:** Document outline, Style guide, Sources, Comparison criteria · **Vault:** none

**Part:** `3. Operational cost` (outline sections `3.1 Pricing model`, `3.2 Monthly cost at 10k users`).
**Sources:** S1, S2 and S4 of the Sources contract. No other source.

**Acceptance criteria:**
1. The part has exactly the two outline headings of its section, spelled as in the Document outline.
2. Every claim ends with a source tag `[S<n>]` that exists in the Sources contract; opinions are marked `Note:`.
3. Each option is scored on the Comparison criteria "Price at 10k users" and "Lock-in" with the same scale.

- [ ] **Step 1: Read sources.** Read S1, S2 and S4 completely. List the facts you will use, each with its source number.
- [ ] **Step 2: Write the part.** Write `<report-dir>/parts/T-004.md` with the headings of your section, following the Style guide. One claim per line.
- [ ] **Step 3: Cite.** End every claim with `[S<n>]`. Remove a claim no source supports, or mark it `Note:` if it is your inference. Report any source you needed that is not in the list under "open questions"; do not add it.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^## ' <report-dir>/parts/T-004.md
  for h in '## 3.1 Pricing model' '## 3.2 Monthly cost at 10k users'; do grep -Fxq "$h" <report-dir>/parts/T-004.md || echo "MISSING $h"; done
  grep -o '\[S[0-9]*\]' <report-dir>/parts/T-004.md | grep -vE '^\[S(1|2|4)\]$'
  grep -vE '^(#|$|\|)' <report-dir>/parts/T-004.md | grep -vcE '\[S[0-9]+\]|^Note:'
  ```
  Expected: `2`; no `MISSING`; no output from the third command, which exits 1 because it selects no line (only allowed tags); and `0` from the last, which also exits 1 because the count is 0 (no line without a tag or a `Note:` prefix).
````

## Rules for document workers

- **Write only the part and the report.** `<report-dir>/parts/<TASK>.md` and `<report-dir>/<TASK>.md`. Sources are never edited.
- **Every claim cites a source** from the Sources contract. A claim without a source is removed or marked `Note:` (the worker's own inference).
- **Distinct parts within a wave.** Two document tasks in the same wave write distinct parts, that is, distinct outline sections. Two tasks never write the same section.
- **The outline is fixed.** A part uses the exact headings of its section. A worker never renames, adds or merges outline sections; it reports the problem as BLOCKED.
- **Deliverable.** The plan records the deliverable decision (path, format `md` or `html`, committed or not) as `to confirm`. For `html`, the consolidation task says `**Deliverable format:** html` (`make-package.sh` allows the `parts/<TASK>.html` write only when the task text says `format: html` or names a `.html` part), and by default its worker generates the `.html` from the `.md` (no renderer in the allowlist); an external render command is used only if the plan records it as a decision, and then it is in the allowlist and the T-000 tool check.

## Consolidation task

Every plan with findings or document tasks has one: kind `document`, in the last wave of findings and document work, before the cross-cutting review, depending on every part. `deliverables/<run-id>/parts/` holds the document parts and the integrated findings parts: for each findings task, the orchestrator copies its findings report there with the reviewer's verdicts applied (the confirmed findings, plus a "Corrected false positives" section with the not reproduced ones). The consolidation reads only that folder.

````markdown
### Task T-008: Consolidate the deliverable

**Kind:** document · **Model:** opus · **Depends on:** T-004, T-005, T-006, T-007 integrated · **Parallel with:** none · **Contracts:** Document outline, Style guide, Sources · **Vault:** none

**Deliverable format:** html (write `md` instead, and drop criterion 3, Step 3 and the html command, when the format is `md`).
**Part:** the whole document, written as `<report-dir>/parts/T-008.md` (the orchestrator places it as `<name>.md` in the deliverable). **Sources:** `deliverables/<run-id>/parts/` (read only): the document parts and the integrated findings parts.

**Acceptance criteria:**
1. The document has an executive summary, every part in outline order, the confirmed findings, a "Corrected false positives" section (gathered from the integrated findings parts) and the recommendation.
2. No part's claim is changed; contradictions between parts are listed in the report instead of silently resolved.
3. When the format is `html`, `<report-dir>/parts/T-008.html` is generated from the `.md`: one file, inline CSS, no network loads, and generated again whenever the `.md` changes.

- [ ] **Step 1: Read the parts.** Read every file in `deliverables/<run-id>/parts/`: the document parts, and the confirmed findings and "Corrected false positives" sections of the findings parts.
- [ ] **Step 2: Write the document** in the order of criterion 1. Keep each part's text and its `[S<n>]` tags.
- [ ] **Step 3: Render** (format `html` only): write the `.html` from the `.md` yourself, as one self-contained file (or run the render command the plan names). Never edit it by hand: fix the `.md` and generate again.
- [ ] **Step 4: Verify.**
  ```bash
  grep -c '^## ' <report-dir>/parts/T-008.md
  # only when the format is html:
  grep -Eic '<script|<link[^>]*href="https?:|src="https?:' <report-dir>/parts/T-008.html
  ```
  Expected: the number of outline sections plus the four fixed ones, and, for `html` only, `0` (exit 1: no match).
````

### Consolidation when the plan has only findings tasks

There are no document parts: the Document outline lists only the fixed sections (executive summary, confirmed findings, "Corrected false positives", recommendation); findings parts are cited by finding ID (`T-001-F02`) instead of `[S<n>]`, so the task lists no Sources contract; and the Verify count is `4`, the fixed sections.

## Contracts

Write the ones the plan needs as `##` sections; a task lists them by exact heading.

**`## Document outline`** (every document task lists it)

```markdown
## Document outline

| Section | Exact heading | Owner | Content |
|---|---|---|---|
| 3 | `## 3.1 Pricing model` | T-004 | How each option charges: units, tiers, free tier |
| 3 | `## 3.2 Monthly cost at 10k users` | T-004 | One number per option with its assumptions |
```

**`## Style guide`**

```markdown
## Style guide

- English, present tense, no first person. Numbers with units and a date (`USD 120/month, 2026-10`).
- One claim per line, ending with its tag `[S<n>]`. Opinions start with `Note:`.
```

**`## Sources`** (numbered `S1…`; parts cite them as `[S1]`)

```markdown
## Sources

| # | Source | Covers | Accessed |
|---|---|---|---|
| S1 | https://acme-queue.example/pricing | List prices | 2026-10-20 |
| S2 | `/srv/acme/api/docs/load-test-2026-09.pdf` | Measured throughput | 2026-10-20 |
```

**`## Comparison criteria`** (research comparisons). Every worker scores every option on the same criteria and scale:

```markdown
## Comparison criteria

| Criterion | Scale |
|---|---|
| Price at 10k users | USD per month, from S1 and the usage in S2 |
| Lock-in | low (open protocol) · medium (export tool) · high (proprietary API) |
```

## T-000 for this kind

T-000 stays with the orchestrator. For a plan with document tasks it:

1. creates `<report-dir>/parts`;
2. proves every source is readable: `test -r /srv/acme/api/docs/load-test-2026-09.pdf`, `curl -sI -o /dev/null -w '%{http_code}\n' https://acme-queue.example/pricing` (200), and the baseline of a repo source as in `kinds/findings.md`;
3. checks every tool the tasks name (`command -v pdftotext`) and that the launch flags exist in `claude --help`.

## Worker environment (example)

```markdown
## Worker environment

- You write; you change no source. Your working directory is `/srv/acme/api`. Read the files listed in your task's Sources freely; never write there.
- You write only `<report-dir>/parts/T-0NN.md` and `<report-dir>/T-0NN.md` (the real paths are in your package).
- Network: GET requests to `https://acme-queue.example` only. No other hosts.
- No credentials are needed. Never touch `.env` files, `SCRATCHPAD.md` or other workers' parts. Read under `deliverables/` only when your task's Sources name it; never write there.
```

## Self-review (document)

- Every document task lists `Document outline` and `Sources`, has a `**Part:**` line naming outline headings that exist in the contract, and cites only source numbers that exist.
- Within a wave, document tasks write distinct outline sections: no heading is owned by two tasks.
- There is a consolidation task (kind `document`, last wave of findings and document work) that depends on every part; the cross-cutting review comes after it, then the reserved fix tasks.
- The deliverable decision (path, format, committed or not) exists and is `to confirm` until the user answers; with format `html`, the consolidation Verify runs the `grep` check.

## Common mistakes (document)

| Mistake | Fix |
|---|---|
| Claims with no source, or sources named in prose instead of `[S<n>]` | Numbered Sources contract; the Verify step counts untagged lines |
| Two workers writing the same outline section, or renaming headings | One owner per heading, exact headings in the Document outline; the Verify step greps them |
| Editing the `.html` by hand | The `.md` is the source; regenerate the `.html` and run the `grep` check |
| Options scored on different criteria per worker | `Comparison criteria` in every comparison task |
