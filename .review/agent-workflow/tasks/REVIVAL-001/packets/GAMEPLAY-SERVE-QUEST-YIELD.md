# GAMEPLAY-SERVE-QUEST-YIELD: quest progress no longer yields inside the NPC serve path
Model: sonnet (Mason, Studio: no; Sentry review after, money path)   Depends on: GAMEPLAY-REVIEW K1 (OBVIOUS fix); same pattern as M4-FIX-REALORDER-QUEST-SENTRY P2   Size: XS

## Goal
`CustomerService:_onServeTriggered` calls `Knit.GetService("QuestService"):AdvanceQuest(player, "CustomersServed", 1)` synchronously inside a pcall (`src/server/Modules/CustomerService/init.luau:813-815`). It runs after the payout (`:802`) but BEFORE `RecordTeamServe` (`:818`), `_clearTicket` (`:835`) and `npc:Leave("Served")` (`:846`). `AdvanceQuest` can yield: `QuestService._getPlayerData` does `GetDataAsync(player):timeout():await()` (`QuestService.luau:63`), and on the first call of a new day `_ensureDailyQuests` calls `_hasPass` → `PlayerOwnsPassAsync` (`:55-59, 85-92`). During that yield the NPC is still `AtCounter` with the prompt live, so a second matching tool (two ticket slots from L5) could be served to it again, and the Team Combo chain update is delayed. A pcall does not stop a yield. Fix: run the quest advance in its own thread, exactly as `RealOrderService` now does for the customer (`RealOrderService.luau:244-252`).

## Serve-path invariant (mandatory)
Nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout (SYSTEMS "Team Combo & the Serve Path"). After this change, nothing on the serve path yields from the guards through the tool destroy, the payout, `RecordTeamServe`, the ticket clear and `Leave`. Do not move, reorder or touch the guards, `FindServeTools`, the tool destroy, pay, `Rules.Payout`, Rush, `ApplyTeamCombo`, `TakeTipExtra`, `Modify`, stats, the leaderboard call, combo or `RecordTeamServe`.

## Write scope
`src/server/Modules/CustomerService/init.luau` only: lines 813-815.
Not touched: `QuestService`, `RealOrderService` (in flight under M4-FIX-REALORDER-QUEST), `ShiftService` (its `AdvanceQuest` at `_endShift` is not on a serve path), any spec unless one asserts the synchronous call (grep `src/server/Tests` for `CustomersServed` + `AdvanceQuest` in CustomerService specs; none found at review time).

## Steps
1. Replace
   ```lua
   pcall(function()
       Knit.GetService("QuestService"):AdvanceQuest(player, "CustomersServed", 1)
   end)
   ```
   with a `task.spawn(function() pcall(function() ... end) end)` at the same position, plus a one-line comment: "AdvanceQuest can yield (data, pass lookups); spawned so the serve path never waits on it."
2. Grep `_onServeTriggered` for any other call that can yield after the tip-bonus line (`GetDataAsync`, `:await()`, `Async(`, `task.wait`, `WaitForChild`). Report findings; change none of them in this lane.
3. Gate and `rojo build`.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio. Do not commit.
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited.
- No economy change; no behaviour change other than the call no longer blocking the serve thread.
- Gate (stylua only if the file has no DEC-001 drift; otherwise gate alone and show no new findings): `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`, plus `rojo build default.project.json -o <path outside the repo>`.
- Sentry reviews the diff before commit (money path).

## Done when
- The diff is the 3-line change plus the comment; gate shows no new findings; `rojo build` succeeds; evidence in `tasks/REVIVAL-001/GAMEPLAY-SERVE-QUEST-YIELD/evidence.md` with the step-2 grep results.

## Test for Jack (Play, his Studio)
- Serve NPCs: the Customers Served quest (if rolled) still advances by 1 per serve; pay, toast and combo unchanged.
- Day rollover (or with the quests' `AssignedDay` set to yesterday in a test profile): the first serve of the day still pays at once and the NPC leaves at once; quests regenerate.
- Level 5+ with two matching drinks: serving one NPC twice in quick succession pays only once.
