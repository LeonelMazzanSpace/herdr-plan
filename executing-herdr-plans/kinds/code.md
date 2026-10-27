# Code tasks

Read this when the plan has code tasks (a task without `Kind` is a code task). The core steps are in `SKILL.md`; this file holds what only code tasks need.

## Stack confirmation

   - **Read:**
     - the repo: `dependencies` and `devDependencies` of the root and each workspace `package.json`, the lockfile, `tsconfig*`, `docker-compose*`, ORM and migration config or folders, CI files, the project `CLAUDE.md`, and the top-level folder layout;
     - the plan: the Tech Stack header, `## Decisions recorded for this plan`, T-000, the contract sections, and the libraries and patterns named in task Files and Interfaces;
     - company defaults the project `CLAUDE.md` or the global one lists, and the vault notes on architecture if the MCP is connected.
   - **Inventory table**, in the user's language, one row per category: `Category · Value · Source · Status`.
     - Categories: package manager, runtime and language, backend framework, **data access (ORM or query builder, e.g. TypeORM, Sequelize, Prisma, Drizzle)**, database engine, migrations tool, auth, validation, API style, frontend framework and build tool, UI kit, state and data fetching, forms, unit and E2E test runners, lint and format, CI and deploy, architecture (module layout, layering, monorepo shape).
     - Source: `repo`, `plan`, `both`, `company default`.
     - Status: `confirmed` (repo and plan agree, or only one names it and the other does not contradict it), `conflict` (repo and plan, or plan and company default, disagree, e.g. the repo has Prisma and the plan says TypeORM), `undecided` (a task needs it and nobody named it), `redundant` (the repo has two libraries for the same job).
   - **Also list what may have been missed:**
     - libraries a task imports that T-000 does not install;
     - a category with tasks but no decision in the plan;
     - two tasks assuming different libraries for the same job;
     - repo conventions (folder layout, naming, test location) the plan's tasks contradict.
   - **Ask once.** Show the table, then only the rows that are `conflict`, `undecided` or `redundant`, each with your recommendation and a one-line tradeoff. A `confirmed` row is shown, not asked about, but the user may change it. Batch into this same message the other questions this preflight needs: permission mode (step 7), keeping the machine awake (step 8) and a ClickUp board decision still `to confirm` (step 9).
   - **After the answer:**
     - record each stack choice as a D-number with status `approved` (user's words as the source) and write a "Stack confirmed" line in the scratchpad with the date;
     - if an answer changes the plan (another ORM, an extra library, a different layout), revise the plan on the coordination branch first: Tech Stack header, T-000 dependencies, and the tasks, contracts and Worker environment it touches. Run the plan's self-review again, record the revision as a D-number, and send `plan revised` to the `clickup` worker once it is running;
     - from here on, run the plan without asking about the stack again. A worker that needs a library outside the confirmed list stops with BLOCKED, as the plan already requires.
   - **No shortcuts.** User urgency does not skip this step; it makes the question shorter. If the user is away, wait: never mark a stack choice `approved` yourself, and never pick between conflicting rows on their behalf. On resume, skip it only when the scratchpad shows "Stack confirmed" and the plan's Tech Stack and T-000 are unchanged since that date.

## Preparing a code task

   - create the worktree and branch from the coordination branch;
   - generate the worktree `.env` as a copy of the coordination `.env` with its own DB and port (never edit the coordination `.env` itself);
   - create its dev and test databases;
   - run `pnpm install --frozen-lockfile`;
   - write `<report-dir>/<task>.vault.md`: reread the notes through the MCP and quote the lines the task needs.

Model order is `haiku` < `sonnet` < `opus`. Herdr `--timeout` values are milliseconds. The task-specific values below (`E2E_DATABASE_NAME`, DB names, ports) come from the plan's "Worker environment" and orchestration sections.

## Accepting a code task

2. `git -C <wt> diff --stat $(git -C <wt> merge-base <coordination-branch> HEAD)...HEAD` touches only the task's allowed files. Use the merge-base, because the coordination branch may have been merged into the task branch.
3. You re-ran the task's Verify commands in the worktree, and they are green.

## Integrating a code task

6. **Merge:** `git merge --no-ff <task-branch>` into the coordination branch.
   - Conflicts are expected only in shared registration files that the plan lists in more than one task (module imports, routes). Resolve them by keeping both sides.
   - Run the **full gate**. Only a green gate makes the task `verified`. Then close that task's panes.

## Failures (code)

| Situation | Action |
|---|---|
| BLOCKED by something you own (T-000 dependencies, a contract, a stale test) | Fix it on the coordination branch and run the gate. Merge the coordination branch into the task branch, re-running install if the lockfile changed. Re-prompt **the same session** with a short message: fix commit, what changed, continue. A narrow out-of-scope edit may be authorized in writing in that prompt; record it as a D-number. |
| Integration gate red after a merge | Stop further merges and find the cause with systematic-debugging. Never edit tests just to make them green. |
| ↳ cause is shared and yours (often a test helper that does not know a new table) | Fix it in an orchestrator commit on the coordination branch, then run the gate again. |
| ↳ cause is the merged task's own code | Send a fix round on its task branch and merge again. If other merges are waiting, `git revert -m 1 <merge>` first; never `reset --hard`. |

## Closing (code)

   - For UI plans, also run the plan's **Final verification**: the E2E, usability and motion pass on desktop and mobile. Read its findings report and open the screenshots yourself; a worker's "PASS" is a claim.
   - Check the usability criteria and the motion audit (durations, easings, reduced motion, hover gating) against the plan's `Animation guidelines`. Critical and Important findings become fix tasks; Minor ones are debt. Design improvement proposals go to the user; do not apply them.

## Red flags (code)

| Thought | Reality |
|---|---|
| "The plan says TypeORM and the repo has Prisma, I'll follow the plan" | Conflicts go to the user in the stack confirmation, before anything is created |
| "The user is in a hurry, skip the stack table" | Urgency shortens the question; it does not skip it |
