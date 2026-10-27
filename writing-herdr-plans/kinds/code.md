# Code tasks

Read this when the plan has code tasks (a task without `Kind` is a code task).

## Task steps

The rest of the task follows the writing-plans task template: Files, Interfaces, numbered **Acceptance criteria**, TDD steps, and a final **Verify and commit** step with exact commands. In the commit step, stage explicit paths only.

## Rules for parallel code workers

- **T-000 belongs to the orchestrator.** It installs every dependency the plan needs, adds scripts, isolates test databases, and runs the gate. Afterwards, workers never touch `package.json` or lockfiles; one that needs a dependency stops with BLOCKED. Check new major versions for module-format breaks: ESM-only packages break CommonJS test runners. T-000 is tooling only: dependencies, scripts, config, test isolation, and framework generators (`nest new`, `create vite`) in a greenfield repo. Shared code is a worker task in wave 1 that replaces the generated files where needed: helpers, module and route registration, test utilities, and the schema and migrations. Tasks in the same wave cannot use each other's output. A wave-1 test that would need another wave-1 utility uses the framework or data source directly.
- **Disjoint files within a wave.** Two tasks in the same wave must not create or modify the same file. Shared registration files (app module, router, barrel exports) are either pre-created by a foundation task or listed as "orchestrator resolves trivial merge conflicts".
- **Test isolation per worker.** Each worker gets its own dev DB, test DB and ports: backend and frontend dev servers too, if a task starts them. A browser smoke task states in its Verify step that it may start servers on its own ports. The test script reads the DB name from an env var, for example `E2E_DATABASE_NAME`. The shared test cleanup helper must truncate every table, including tables added by later tasks.

## E2E, usability and motion task

- **E2E, usability and motion task (plans with a UI).** After the last feature task, plan one task `E2E, usability and motion pass`, on `sonnet` (`opus` if the app has payments or auth flows). It is test-and-evidence only: it adds files under the e2e folder and writes a findings report, and never edits app code. Its findings become fix tasks. Its Contracts list includes `Animation guidelines`, copied from `animations-guidelines.md` in this skill.
  - **Functional E2E:** the critical flows of each role, on a desktop viewport and a mobile viewport (touch enabled), against local servers on the worker's own ports.
  - **Usability, as tasks, not pages.** For each role, write 3–5 goal-based tasks in the plan (e.g. "a client books a class and pays"), each with a measurable pass criterion: reachable in at most N steps, a visible response to every action (loading, success, error), error messages that say what to do next, empty, loading and error states present, keyboard reachability and visible focus, touch targets of at least 44px on mobile, and no horizontal scroll at 360px. Each failed criterion is a finding with a screenshot.
  - **Motion audit** against the Animation guidelines, using the "Checks" table in that file: durations, allowed easings, hover transitions gated by `(hover: hover) and (pointer: fine)`, `prefers-reduced-motion` run, origin-aware popovers, transform and opacity only. Run key flows with `reducedMotion: 'reduce'` as well.
  - **Evidence:** a Playwright run with screenshots (and a trace or video for the transitions it judged). Findings are classified Critical, Important or Minor like review findings; a worker may not waive one.
  - **Design improvement notes.** Where the audit shows the design system could be better (inconsistent durations, missing states, weak feedback), the report lists them as proposals, labeled as proposals, never applied by this task.
  - A plan without UI omits the task and says so in the Orchestration section.

## Self-review (code)

2. No file appears in two tasks of the same wave, except declared shared registration files.
3. Every dependency any task uses is installed in T-000.
8. UI plans: the `## Animation guidelines` contract section exists, every UI task lists it in its Contracts, and the E2E, usability and motion task has usability tasks with measurable criteria for every role. A plan without UI says so.

## Common mistakes (code)

| Mistake | Fix |
|---|---|
| A new branch per attempt | One branch per task; fix rounds add commits on top (no amend or rebase) |
| Dependencies added by whichever task first needs them | All in T-000; a worker needing one stops with BLOCKED |
| E2E step that only clicks through happy paths and asserts "page loads" | Usability tasks with measurable criteria per role, plus the motion audit; both produce screenshots and a findings report |
| Animation rules left to each UI worker's taste | `## Animation guidelines` as a contract section in every UI task |
