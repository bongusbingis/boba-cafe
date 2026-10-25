# M4-QUESTS: Daily Quests System & Game Loop Hooks
Model: sonnet / spark   Studio: no   Depends on: none   Size: M

## Goal
Implement the Daily Quests system (`QuestService`) and connect core game loop actions (revival-plan §4.7):
- 3 daily quests refreshed at UTC midnight, drawn from existing gameplay actions.
- +1 quest slot for owners of `Star Employee` (219650999) or `More Quests` (12385834).
- 1 free daily quest reroll for owners of `Star Employee`.
- Server-side `QuestService` with progression tracking, reward claims (BobaBucks + XP), and reroll.
- Hook into `CustomerService` (serve customer), `SpillService` (clean spill), `RealOrderService` (serve real player), and `ShiftService` (complete shift). (`OrderService` already has `self._questService:AdvanceQuest` wired!).

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `src/shared/Configuration/ProfileTemplate.luau` (Quests schema)
- `src/server/Modules/OrderService.luau` (lines 725-740: existing `_questService:AdvanceQuest` call)
- `src/server/Modules/CustomerService/init.luau` (lines 720-745: customer serve point)
- `src/server/Modules/SpillService/Spill.luau` or `init.luau` (spill cleaned point)
- `src/server/Modules/RealOrderService.luau` (lines 200-240: player order complete point)
- `src/server/Modules/ShiftService.luau` (lines 90-120: shift complete point)
- `src/server/Modules/ProgressionService.luau` (AddXP method)
- `src/server/Modules/CurrencyService.luau` (Modify method)

## Write scope
- `src/shared/Configuration/QuestConfig.luau` (new)
- `src/server/Modules/QuestService.luau` (new)
- `src/server/Tests/QuestService.spec.luau` (new)
- `src/server/Modules/CustomerService/init.luau` (add QuestService hook on serve)
- `src/server/Modules/SpillService/init.luau` (add QuestService hook on spill cleaned)
- `src/server/Modules/RealOrderService.luau` (add QuestService hook on real order served)
- `src/server/Modules/ShiftService.luau` (add QuestService hook on shift completed)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-QUESTS/evidence.md` (new)

## Steps
1. Create `src/shared/Configuration/QuestConfig.luau`:
   - `BASE_SLOTS = 3`
   - `BONUS_SLOT_PASSES = { 219650999, 12385834 }` (Star Employee, More Quests)
   - `FREE_REROLL_PASS = 219650999` (Star Employee)
   - `TEMPLATES`:
     - `BobaOrdered`: `{ Title = "Prepare %d Boba Drinks", Targets = { 3, 5, 8 }, BobaBucks = 50, XP = 25 }`
     - `CustomersServed`: `{ Title = "Serve %d Customers", Targets = { 5, 10, 15 }, BobaBucks = 60, XP = 30 }`
     - `SpillsCleaned`: `{ Title = "Clean %d Spills", Targets = { 2, 4, 6 }, BobaBucks = 40, XP = 20 }`
     - `RegularOrders`: `{ Title = "Serve %d Real Players", Targets = { 1, 2 }, BobaBucks = 75, XP = 40 }`
     - `ShiftsCompleted`: `{ Title = "Complete %d Shifts", Targets = { 1, 2 }, BobaBucks = 50, XP = 25 }`
   - `QuestConfig.GetCurrentDay(): number`: returns `math.floor(os.time() / 86400)`
   - `QuestConfig.GenerateDailyQuests(dayNumber: number, slotCount: number): { QuestEntry }`
2. Create `src/server/Modules/QuestService.luau`:
   - Knit service named `"QuestService"`.
   - `GetQuests(player: Player): { QuestEntry }`:
     Reads player profile `Quests`. If `Quests.AssignedDay ~= currentDay`:
     - Determines slot count (`BASE_SLOTS` + 1 if player owns bonus pass).
     - Generates new daily quests.
     - Sets `Quests.AssignedDay = currentDay`, `Quests.ActiveQuests = newQuests`, and resets `FreeRerollsRemaining` (1 if owns Star Employee, else 0).
     Returns `Quests.ActiveQuests`.
   - `AdvanceQuest(player: Player, questType: string, amount: number)`:
     Ensures quests are current for today. Iterates `ActiveQuests`; for each matching `quest.Type == questType` and not `Completed`:
     - `quest.Progress = math.min(quest.Target, quest.Progress + amount)`
     - If `quest.Progress >= quest.Target`, sets `quest.Completed = true`.
   - `ClaimQuest(player: Player, questIndex: number): (boolean, string?)`:
     Validates quest at `questIndex` exists, is `Completed`, and not yet `Claimed`.
     - Marks `quest.Claimed = true`.
     - Grants BobaBucks via `CurrencyService:Modify(player, "BobaBucks", quest.RewardBobaBucks, "QuestReward")`.
     - Grants XP via `ProgressionService:AddXP(player, quest.RewardXP)`.
     - Returns `true`.
   - `RerollQuest(player: Player, questIndex: number): (boolean, string?)`:
     Allows rerolling an unclaimed quest using a free reroll or 50 BobaBucks.
   - Client functions: `GetQuests`, `ClaimQuest`, `RerollQuest`.
3. Add hook points:
   - In `CustomerService/init.luau` (when barista serves customer successfully):
     `pcall(function() Knit.GetService("QuestService"):AdvanceQuest(player, "CustomersServed", 1) end)`
   - In `SpillService/init.luau` (when spill is cleaned by player):
     `pcall(function() Knit.GetService("QuestService"):AdvanceQuest(cleaner, "SpillsCleaned", 1) end)`
   - In `RealOrderService.luau` (when barista serves a player order):
     `pcall(function() Knit.GetService("QuestService"):AdvanceQuest(serverPlayer, "RegularOrders", 1) end)`
   - In `ShiftService.luau` (when player completes a shift):
     `pcall(function() Knit.GetService("QuestService"):AdvanceQuest(player, "ShiftsCompleted", 1) end)`
4. Create `src/server/Tests/QuestService.spec.luau`:
   - TestEZ spec covering:
     - Day transition and fresh quest generation.
     - Progress advancement by quest type.
     - Quest completion and reward claim idempotency (cannot claim twice).
     - Bonus slot calculation with GamepassUtil mock.
5. Run WSL gate and verify clean output.

## Done when
- `QuestConfig.luau` provides quest templates and daily generator.
- `QuestService.luau` correctly advances quest progress across all 5 action types.
- Service hooks are wired without breaking existing behaviors or tests.
- `QuestService.spec.luau` passes.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/QuestConfig.luau src/server/Modules/QuestService.luau src/server/Tests/QuestService.spec.luau src/server/Modules/CustomerService/init.luau src/server/Modules/SpillService/init.luau src/server/Modules/RealOrderService.luau src/server/Modules/ShiftService.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-QUESTS/evidence.md`
