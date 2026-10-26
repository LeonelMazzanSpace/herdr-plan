# Hand-off template

Two blocks. The outgoing orchestrator writes the first one into `SCRATCHPAD.md` under "Next steps and recovery" after the relief is started (so its pane id and effective model are known), then saves the second one as `<report-dir>/handoff-orch-<N>.md` and prompts the relief with "Read <report-dir>/handoff-orch-<N>.md and execute it exactly." Replace every `<…>` except `<the current time>` in block 2, which the relief fills; `a | b` means pick one; the table rows are examples. `<N>` is the relief's number (the first relief is `orch-2`). Write absolute paths everywhere (expand `~`): the relief reads them with its file tools. Fill the agents table from a fresh `herdr agent list`, and the layout from `herdr pane layout --pane "$HERDR_PANE_ID"`.

## 1. Scratchpad entry

```markdown
### Hand-off to orch-<N> — <YYYY-MM-DD HH:MM TZ>
Outgoing: orch-<N-1> (pane <your $HERDR_PANE_ID>), context <NN>% · Relief: orch-<N> (pane <relief pane id>, effective model <as read from its status line | not verified>)
Launch: model <alias> (D<n>), permission mode <mode> (D<n>), cap <N> panes (D<n>), report dir <report-dir>, plan <plan path>
Safe point: <what just finished, e.g. "T-004 merged, gate green at <sha>"; nothing is half done>
Deliverable: <parts integrated / missing, consolidation state | not applicable>
Layout: column A <pane ids>, column B <pane ids | none>

Live agents (the relief re-arms one background `herdr agent wait NAME --timeout 3600000` per `working` row):
| Agent | Pane | State | Worktree | Will write |
| --- | --- | --- | --- | --- |
| t005 | <pane> | working | <wt> | <report-dir>/T-005.md |
| t003-r1 | <pane> | working | <wt> | <report-dir>/T-003.review.md (implementer session already exited: a fix round goes to a fresh t003-f1) |
| clickup | <pane> | idle | – | <report-dir>/clickup-map.json |

Queued ClickUp events (only those whose send failed): <none | "T-004 → verified | gate green <sha>" …>
Next action: <the exact next step, e.g. "when T-005.md appears, run Accepting a Task; T-006 is prepared in <wt>, package written, not dispatched only because of the 70% reading: dispatch it to the column with fewer panes">
Open questions for the user: <none | …>
```

Everything the relief needs must be in this entry, the plan, the D-numbers and the report dir. Nothing in your chat survives.

## 2. Relief prompt (`<report-dir>/handoff-orch-<N>.md`)

```markdown
You are orch-<N>, the relief orchestrator of run <run-id>, in pane <relief pane id>. The previous orchestrator, orch-<N-1> (pane <pane id>), is handing you the run because its context reached 70%. It is waiting for your confirmation and does nothing else; you close its pane once it is idle.

Do, in this order:
1. Load the executing-herdr-plans skill and follow "As the relief" in its Handing Off section, starting with its preflight.
2. Read <COORDINATION_ROOT>/SCRATCHPAD.md in full; your starting point is the last "Hand-off to orch-<N>" entry. Then read the plan <plan path> and its summary. Do not redo T-000 and do not ask about the stack again: it is confirmed in the scratchpad.
3. Append a `Resumed by orch-<N> at <the current time>` line to the scratchpad's "Recent activity". From that line, you are the only writer.
4. Reconcile with `herdr agent list`, `git worktree list` and <report-dir>; re-arm one background wait per `working` agent in the entry; send the queued ClickUp events, if any.
5. Wait until orch-<N-1> is idle (never close it while working), then close its pane: `herdr pane close <pane id>`. Focus yourself and tell the user in one line that you own the run.
6. Continue the wave loop from "Next action". Keep checking your own context; at 70%, hand off to orch-<N+1> the same way.
```
