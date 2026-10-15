# SCRATCHPAD.md template

`COORDINATION_ROOT/SCRATCHPAD.md` has one writer: the orchestrator. It is the compact, factual view of the whole run. Timestamp every update with date, time and time zone. Write the state first, then report to the user.

Update it after each of these: creating or revising the plan, delegating, receiving a result, a decision, a merge, a gate, a blocker. Also update it before the session ends or before an expected context compaction.

Working states: `planned`, `dispatched`, `blocked` (say on what), `in review`, `changes required` (fix round N).

Status words have fixed meanings:
- `implemented` — the report file says PASS and you have read it;
- `reviewed` — an independent reviewer approved it;
- `integrated` — merged into the coordination branch;
- `verified` — the gate passed after the merge;
- `completed` — all of the above, with the acceptance criteria met.

Track vault sync separately. When the file grows large, move old history to `.claude/scratchpad-history/<date>-<run>.md`, link it, and keep only the current state, open decisions, blockers and recovery steps.

```markdown
# Scratchpad — <project>
Updated: <YYYY-MM-DD HH:MM TZ> | Run: <run-id> | Status: <planning | executing — wave N | completed — …>

## Objective and current scope
<Expected result, boundaries, and overall completion criteria>

## Current state
<What works, what is running (panes, dev servers), the next expected result>

## References and environment
<COORDINATION_ROOT, coordination branch and base, spec, plan, plan summary, vault and notes read>
<Verified versions: herdr, Claude Code (launch flags), Superpowers, vault MCP; failed MCPs and the workaround>
<Report dir; worktree root; database naming>

## Tasks and agents
| ID | Task | Status | Dependencies | Agent/pane | Model/rationale (effective) | Worktree/branch | Evidence |
| --- | --- | --- | --- | --- | --- | --- | --- |

## Remaining work and blockers
<Item, impact, owner, action required. Use "not applicable" with a reason where it fits.>

## Decisions and discrepancies
<D-number, decision, rationale, source, date; deviations from the plan; DAG deviations>

## Overall verification
<Gate commands and results, the commit tested, what still needs to run>

## Obsidian synchronization
<Notes consulted, verified changes, queued updates if the MCP failed>

## Next steps and recovery
<Immediate sequence; live agents and panes; unintegrated work; how to resume: read this file + plan, `git worktree list`, `herdr agent list`, reports in <report-dir>>

## Recent activity
<YYYY-MM-DD HH:MM TZ — task/event — result — evidence>
```
