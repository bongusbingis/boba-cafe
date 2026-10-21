# REVIVAL-001 TAKEOVER-FIX (branch uhweifh, 2026-10-21)

Gates on every commit: selene 0 new findings and `stylua --check` clean on changed files,
`rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/tf.rbxlx` OK.

| Fix | Commit | Change |
| --- | --- | --- |
| 1 | 94e6dcf | PourMoments.AwaitPour resolves through one idempotent `finish`; never `task.cancel`s its own thread. New PourMoments.spec (6 cases). |
| 2 | c52bb5e | Register patience (same ramp x REGISTER_PATIENCE_MULT, walkout drops rating), line gives up after QUEUE_PATIENCE_SECONDS, auto-assign removed, clock-out hands every ticket off. |
| 2b | abddac6 | `Npc:884 attempt to call a nil value` root cause: RegisterPatience call unguarded; now pcall + base-patience fallback. |
| 3 | 1555790 | Register order rolled once per NPC; submit only for the player's own tablet, re-checks free slot and range; first-session script carried through. |
| 4 | 9e67036 | LeaderboardService: bounded 10 s folder wait, OldScriptables fallback, clean disable with a warning. |
| 5 | 1532d14 | Drink clone onto NPC only when seating is on; B4SeatingForce guarded by RunService:IsStudio(). |

New config (all "DEC-058 agent-set, Jack to tune"): CustomerConfig REGISTER_PATIENCE_MULT 1,
REGISTER_TAKE_ORDER_GRACE_SECONDS 30, QUEUE_PATIENCE_SECONDS 120; CustomerService
SUBMIT_MAX_DISTANCE_STUDS 20; LeaderboardService BOARDS_WAIT_SECONDS 10.
"No tap = Poor" kept on every pour station including the Sink (Jack-confirmed).

## Studio checks (Studio MCP, "jacks project")

- Fix 1 P1 confirmed: `pcall(task.cancel, <running thread>)` returns `false, "cannot cancel thread"`.
  The old timeout/walk-away paths therefore threw inside cleanup and never resumed the awaiting
  thread, pinning InteractionRunner's station lock.
- PourMoments.spec in Edit (Rojo-synced source): 6/6 pass (timeout = Poor, walk-away, unequip,
  leave, tap + late tap ignored, second pour cancels first; no pending state left on any path).
- CustomerService.spec + PourMoments.spec in a running Play server: 118/118 pass;
  with LeaderboardService.spec: 135/135 pass. (Play-mode source is the snapshot at Play start,
  so the fix 4 source was not in that run; LeaderboardService.spec does not cover KnitStart.)
- Live Play server (someone else's session, B4Stress auto-serve on): context has RegisterPatience;
  NPCs cycle AtCounter -> Served -> Leaving with no despawn errors over 40 s.
- Npc:884 error: seen only in a Play session that started while Npc.luau had the call but
  init.luau did not yet have the context entry (two-step write under Rojo live sync).
- Not run (needs a full Play with a clocked-in tester): a register walkout dropping the rating,
  a line give-up after 120 s during Rush, hand-off on clock-out, tablet re-press showing the
  same order, submit refused when slots are full, leaderboard warning with the folder removed.
  Full suite via `workspace:SetAttribute("RunTests", true)` still owed after the next Play restart.
