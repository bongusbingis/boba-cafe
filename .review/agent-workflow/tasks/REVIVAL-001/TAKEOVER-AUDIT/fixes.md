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

# REVIVAL-001 TAKEOVER-REVIEW-FIX (review.md findings, 2026-10-21)

All findings re-checked at f31680b before fixing; all still present. Gates per commit: selene 0 findings
on changed files, `stylua --check` clean (LF copies), `rojo build ... -o C:/Users/jackc/AppData/Local/Temp/f2.rbxlx` OK.

| Finding | Commit | Change |
| --- | --- | --- |
| P2-1 | 00f77bc | Ordering page reads its NPC only from Args (no ActiveNpcOrder fallback) and clears ActiveNpcOrder on unmount; Take Order always opens (never toggles) and re-mounts for a new NPC. |
| P2-2 | f48fa7f | Pour meter: E / Space / ButtonA / ButtonR2 via ContextActionService at High+50, bound only while a window is open, unbound on every hide. |
| P2-3 | efc3324 | 0 baristas -> pacing target 0 (no rush crowd). Rush floor = min(RUSH_MIN_TARGET 25, RUSH_MIN_PER_BARISTA 8 x baristas). After EMPTY_CAFE_DISMISS_SECONDS 60 with nobody on, waiting NPCs leave quietly (LineGaveUp). |
| P2-4 | a62a303, 4f215d4 | Deltas also queue to the all-time store (own pending entry). Global boards read all-time, Monthly read month, each once per refresh. Most Boba Bucks / Top Donators reuse the pre-revival stores `MostBobaBucks_V3_01` / `TopDonators_V3_01` (main a476819 naming); Orders Served / Most Active use `AllTime_<board>`. |
| Specs | 0d5a5cd | GetMonthKey uses `os.date("!...")`; rollover spec hardcodes 2026_11_/2026_10_/2027_01_. Recipe Book grab spec asserts the pastry block with its Food Display step. Hidden-boards spec follows the Top Donators unhide (bdd9561). |
| P3-5 | 5da67a7 | Level-up moves EquippedTitle to the new level title only when the player still wore the previous highest one. |
| P3-7 | e4266b9 | Weekly claim checks AssignedWeek after the capsule grant; a rollover is never overwritten. |
| P3-8 | 124d6f0 | NPC serves advance BobaOrdered by the boba items served (customer-pickup credit kept). |
| P3-9 | 9820bfe | Shift with Served == 0 resets the streak to 0. New spec case. |
| P3-3 | 3ef577f | _onAtPickup re-sends the holder's ticket with PatienceEnd/PatienceTotal. |

New config ("DEC-058 agent-set, Jack to tune"): CustomerConfig EMPTY_CAFE_DISMISS_SECONDS 60;
RatingConfig RUSH_MIN_PER_BARISTA 8.

PENDING JACK: pre-revival Global stores `MostStaffPoints_V3_01` (staff points) and `MostActive_V3_01`
(seconds) hold different units from Orders Served / Most Active (minutes), so they are untouched, not
merged. Their Global boards start from this build. The `_V3_01` suffix is from main's config; the live V3
suffix came from a ServerScriptService attribute and was not verifiable here (the Studio test place's
stores are all empty).

Skipped: P3-1/P3-2 pour claim bound (already clamped to 0.3 s and tip-capped; tightening it hurts
high-ping players, P3-2 needs a GetServerTimeNow redesign), P3-4 ValidateSubmittedOrder shape guard,
P3-6 Titles/Staff "Equipped" display (UI files under UI-revision edits), P3-10 pickup overflow stacking.

## Studio checks

- Studio was in someone else's Play session; not stopped. Read-only Server queries: Content.build(nil, 1)
  contains the asserted Fudge Brownie block; `os.date("!%Y_%m_")` gives 2026_11_ at Nov 1 00:00 UTC and
  2026_10_ one second earlier; the legacy `_V3_01` and `AllTime_` stores are empty in this place.
- TestEZ not run: Play-mode source is the Play-start snapshot. Owed after the next Play restart:
  LeaderboardService, RecipeBookContent, ShiftService, CustomerService specs (`RunTests` attribute).
- Manual checks owed: gamepad/keyboard pour tap (and that Space/A don't jump mid-pour); Take Order twice
  / HUD switch then register "Use Ordering System" shows a player order; Boba Party with 0 baristas
  spawns nobody and a crowd leaves 60 s after the last clock-out; ticket bar visible at pickup.
