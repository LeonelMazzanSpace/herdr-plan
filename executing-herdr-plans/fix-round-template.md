# Fix round template

Save this as `<report-dir>/<task>.fix-a<N>.md`, replacing every `<…>`. Then prompt the worker with: "Read <report-dir>/<task>.fix-a<N>.md and execute it exactly."

```markdown
# <TASK> fix round (attempt <N>) — orchestrator instructions

You are <a NEW worker continuing | the same worker continuing> <TASK> in its existing worktree <path> (branch <branch>; the implementer commit(s) <sha…> are present).
Read first:
- the original package <report-dir>/<TASK>.package.md (scope, contracts, constraints);
- the implementer report <report-dir>/<TASK>.md;
- the latest review <report-dir>/<TASK>.review[-a<N>].md (verdict CHANGES_REQUIRED: <n> Critical, <n> Important), and earlier reviews of this task if any.

Required:
- Fix every Critical and Important finding. TDD: first add the test that reproduces each finding, see it fail, then fix it.
- Look for the same defect pattern in every other place your task owns (e.g. other paginated or joined queries, other DTO fields), and fix it there too.
- Fix the cheap Minor findings inside your allowed files and contracts. For each Minor you skip, say why.
- <Orchestrator rulings, e.g. "D17: use FOR NO KEY UPDATE instead of the plan's FOR UPDATE", or "authorized: you may edit <file> only to <narrow change>".>
- No contract changes, no dependency or lockfile changes, no migrations unless the finding requires them. Add new commits on top: no amend, rebase or push.

Verify (the test DB env var is already exported): <task verification commands> <plus, for flaky or race findings: run the relevant test 3 extra times>.
Append an "Attempt <N> (fix round)" section to <report-dir>/<TASK>.md with:
- the model you ran as;
- the commit(s) and files changed;
- the observed test results;
- each finding marked fixed or skipped, with the reason.

End with STATUS: PASS|FAIL|BLOCKED and REPORT: <report-dir>/<TASK>.md. Do not edit the global scratchpad or Obsidian. Do not delegate to other Herdr agents.
```

After the fix round, send a scoped re-review: a new review package with the next attempt number (`--attempt 2`, then 3, …), whose notes point the reviewer at the fix commits and ask it to verify every original finding.
