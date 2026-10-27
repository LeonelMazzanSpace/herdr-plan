# Herdr orchestration skills

Two Claude Code skills that move the way an orchestrated run works out of the project's `CLAUDE.md`. A Claude orchestrator plans and coordinates independent Claude Code workers in Herdr panes. They run code, audits, research, documentation, proposals and migration plans; code workers each get their own git worktree.

| Skill | When it is used |
|---|---|
| [`writing-herdr-plans/`](writing-herdr-plans/SKILL.md) | To write the implementation plan from an approved spec. It builds on `superpowers:writing-plans` and adds the decisions, fixed contracts, waves with a model per task, each worker's environment and the fixed headings. |
| [`executing-herdr-plans/`](executing-herdr-plans/SKILL.md) | To execute that plan: confirm the stack (code) or scope and access (other kinds), prepare the worktrees, generate the packages, launch the workers, accept, review, integrate behind a gate, close the run and resume it. |

They are used together: the first writes the plan with fixed headings and the second uses them to cut each worker's package.

## Flow

1. **Plan** (`writing-herdr-plans`): the approved spec becomes a plan with decisions, contracts, waves and one task per worker, plus a summary in the user's language.
2. **Confirm the stack (code) or scope and access (other kinds)** (`executing-herdr-plans`, preflight): before creating anything, the orchestrator reads the repo and the plan. For code it shows you a table of libraries and architecture (ORM, database, migrations, auth, frontend, tests, CI, structure) and flags conflicts between repo and plan, missing decisions, and libraries a task uses that T-000 does not install. For audits, research and documents it confirms the scope, the sources and the access the workers need. You confirm or correct; it is the only initial stop.
3. **Execute on its own**: the orchestrator runs the plan wave by wave. One worker implements each task, another reviews it, and it is integrated behind a full gate after every merge.
   - The orchestrator reads its own context usage from its Herdr pane. At 70% it writes a hand-off entry in `SCRATCHPAD.md`, starts a relief orchestrator in a new pane, waits for it to confirm, and leaves; the relief closes the old pane and continues. It never relies on context compaction. Your status line must show the percentage (`ctx:N%`).
4. **Verify and close**: plans with an interface get a final step covering E2E, usability and animations, a cross-cutting review, vault and board sync, and the summary for the user.

## Kinds of task

Each task in a plan has a kind, written as `**Kind:** <kind>` in its header. A task without `Kind` is `code`, so plans written before kinds existed run unchanged.

| Kind | What the worker delivers |
|---|---|
| `code` | Code on its own branch, with tests and a green Verify. |
| `findings` | A findings report with evidence, from read-only access (audits, QA passes, reviews of something that exists). |
| `document` | A document part with sources (a report section, a comparative research, a migration plan, documentation, a proposal). |

Plans can mix kinds, for example audit first and fix in code later. Findings and document workers never write to the repo: they write only their report, evidence and part, under the run's report folder.

A plan with findings or document tasks ends in a deliverable, in `.md` or `.html` (chosen per plan). The `.md` is the source; the `.html` is generated from it as one self-contained file, never edited by hand. Where it lives is a `to confirm` decision per plan:

- by default, `deliverables/<run-id>/` in the project, committed on the coordination branch;
- when the evidence is sensitive, the same layout outside the repo, not committed.

## What each skill includes

```
writing-herdr-plans/
├── SKILL.md                          Plan rules, model per task, self-review
├── orchestration-section-template.md Orchestration and Worker environment sections
├── animations-guidelines.md          Animation guide ("Animation guidelines" section of the plan)
└── kinds/                            Plan rules per kind: code.md, findings.md, document.md

executing-herdr-plans/
├── SKILL.md                          Preflight, wave loop, acceptance, closing, resuming
├── scratchpad-template.md            SCRATCHPAD.md template
├── fix-round-template.md             Fix round template
├── handoff-template.md               Hand-off to a relief orchestrator (scratchpad entry + prompt)
├── kinds/                            Execution rules per kind: code.md, findings.md, document.md
└── scripts/
    ├── make-package.sh               A worker's package, cut from the plan
    └── make-review-package.sh        The reviewer's package (read-only)

tests/
├── run.sh                            Runs every test
├── fixtures/                         Sample plan the tests cut packages from
├── test-*.sh                         Tests for the scripts and the moved-text check
├── check-moved-text.sh               Checks that code know-how moved verbatim
└── allowed-changes/                  Lines the move is allowed to change
```

### Stack confirmation

It is step 4 of the `executing-herdr-plans` preflight. Each row of the table has a status:

| Status | Meaning |
|---|---|
| `confirmed` | The repo and the plan agree, or only one names it and the other does not contradict it. |
| `conflict` | The repo and the plan, or the plan and the company defaults, disagree (for example the repo uses Prisma and the plan says TypeORM). |
| `undecided` | A task needs it and nobody named it. |
| `redundant` | The repo has two libraries for the same job. |

You are only asked about `conflict`, `undecided` and `redundant`, with a recommendation and a one-line tradeoff. Whatever is confirmed is recorded as an `approved` decision in the plan and the scratchpad. If your answer changes the plan, it is revised before starting.

Findings and document tasks get the same step as a scope and access confirmation (sources, access, deliverable), described in `executing-herdr-plans/kinds/findings.md` and `executing-herdr-plans/kinds/document.md`.

### E2E, usability and animations

In plans with an interface, `writing-herdr-plans` adds a task after the last feature. It only writes tests and a report, and never touches the app's code:

- functional E2E of each role's critical flows, on desktop and on mobile with touch;
- usability tasks per role with measurable criteria (maximum steps, visible feedback, empty, loading and error states, keyboard focus, touch targets of at least 44px, no horizontal scroll at 360px);
- a motion audit against [`animations-guidelines.md`](writing-herdr-plans/animations-guidelines.md): durations, allowed easings, hover only on hover-capable devices, `prefers-reduced-motion`, animations that originate from their trigger, only `transform` and `opacity`;
- screenshots and a findings report. Critical and Important findings become fix tasks; design improvements stay as proposals.

The plan copies the guide as an `## Animation guidelines` section and lists it in the Contracts of each UI task.

## Requirements

- Herdr, with the Claude integration (`herdr integration install claude`), and the orchestrator running inside a pane (`HERDR_ENV=1`);
- Claude Code;
- the `herdr` and `herdr-agent-orchestration` skills;
- the Superpowers plugin (`superpowers:writing-plans`, `verification-before-completion`, `receiving-code-review`, `systematic-debugging`);
- bash. The scripts work with macOS's bash 3.2;
- optional:
  - an Obsidian MCP, if the project has a vault;
  - the ClickUp MCP, if the plan mirrors progress on a board (a `clickup` worker creates and edits the tasks).

### Setup

1. Herdr and Claude Code installed. Check with `herdr --version` and `claude --version`.
2. Herdr integration with Claude Code:

   ```bash
   herdr integration install claude
   herdr integration status      # must show: claude: current
   ```

3. Herdr skills:

   ```bash
   npx skills add herdrdev/herdr --skill herdr -g
   npx skills add aerain/herdr-agent-orchestration -g -s herdr-agent-orchestration -a claude-code
   ```

4. Superpowers, inside Claude Code:

   ```
   /plugin install superpowers@claude-plugins-official
   ```

## Installation

Clone the repo and link each skill into your personal skills folder, from the repo root:

```bash
ln -s "$PWD/writing-herdr-plans" ~/.claude/skills/writing-herdr-plans
ln -s "$PWD/executing-herdr-plans" ~/.claude/skills/executing-herdr-plans
```

To use them in a single project only, link them into that project's `.claude/skills/` folder.

The scripts in `executing-herdr-plans/scripts/` are run with `bash <script>`, never by their direct path.

## Usage

- Ask "write the plan to execute it with herdr" from an approved spec and `writing-herdr-plans` is used.
- Ask "execute the plan", "status" or "continue" and `executing-herdr-plans` is used. It resumes from `SCRATCHPAD.md`.

Decisions that change scope, destructive or sensitive actions, and pushes, PRs or merges into shared branches always go through you. The orchestrator decides everything else and records it as a numbered decision.
