RESULT: PASS
Files changed:
- src/shared/Configuration/QuestConfig.luau (new)
- src/server/Modules/QuestService.luau (new)
- src/server/Tests/QuestService.spec.luau (new)
- src/server/Modules/CustomerService/init.luau (modified)
- src/server/Modules/SpillService/init.luau (modified)
- src/server/Modules/RealOrderService.luau (modified)
- src/server/Modules/ShiftService.luau (modified)

Gate check output:
```
PASS  src/shared/Configuration/QuestConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/QuestService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/QuestService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/SpillService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/ShiftService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `QuestConfig.luau`:
  - Defines 5 quest templates with target tiers and rewards:
    - `BobaOrdered`: "Prepare %d Boba Drinks", Targets: { 3, 5, 8 }, BobaBucks = 50, XP = 25
    - `CustomersServed`: "Serve %d Customers", Targets: { 5, 10, 15 }, BobaBucks = 60, XP = 30
    - `SpillsCleaned`: "Clean %d Spills", Targets: { 2, 4, 6 }, BobaBucks = 40, XP = 20
    - `RegularOrders`: "Serve %d Real Players", Targets: { 1, 2 }, BobaBucks = 75, XP = 40
    - `ShiftsCompleted`: "Complete %d Shifts", Targets: { 1, 2 }, BobaBucks = 50, XP = 25
  - Constants: `BASE_SLOTS = 3`, `BONUS_SLOT_PASSES = { 219650999, 12385834 }`, `FREE_REROLL_PASS = 219650999`, `REROLL_COST_BOBABUCKS = 50`.
  - Helpers:
    - `GetCurrentDay(now)`: returns `math.floor((now or os.time()) / 86400)`.
    - `GetQuestTitle(entry)`: formats title with target number.
    - `GenerateDailyQuests(dayNumber, slotCount, rngOrSeed)`: Fisher-Yates shuffles quest types to pick distinct types per day up to `slotCount`, picking targets from template tiers.
    - `RollQuest(dayNumber, excludeTypes, rng)`: generates replacement quest excluding currently active types for rerolls.
- `QuestService.luau`:
  - Knit Service providing `GetQuests`, `AdvanceQuest` (with `Progress` alias), `ClaimQuest`, and `RerollQuest`.
  - Client table functions `GetQuests`, `ClaimQuest`, `RerollQuest` and signal `QuestsUpdated`.
  - Daily generation logic resets `FreeRerollsRemaining` (1 if owns Star Employee pass 219650999, 0 otherwise) and calculates slots (3 base + 1 if owns Star Employee 219650999 or More Quests 12385834).
  - Rewards paid out idempotently: marks `Claimed = true`, pays BobaBucks via `CurrencyService:Modify` ("QuestReward"), and XP via `ProgressionService:AddXP`.
  - Reroll mechanism consumes 1 free reroll if available, or charges 50 BobaBucks if balance is sufficient, replacing the quest with an uncompleted quest of an unused type.
  - Concurrency locks (`claimsInProgress`, `rerollsInProgress`) prevent double-claim and double-spend race conditions.
  - Legacy `More Quests` (12385834) pass registered to `GamepassUtil.Gamepasses` cache to prevent lookup warnings.
- Hook points wired:
  - `CustomerService/init.luau`: `QuestService:AdvanceQuest(player, "CustomersServed", 1)` upon successful customer serve.
  - `SpillService/init.luau`: `QuestService:AdvanceQuest(cleaner, "SpillsCleaned", 1)` when a spill is cleaned by a player.
  - `RealOrderService.luau`: `QuestService:AdvanceQuest(barista, "RegularOrders", 1)` when a barista serves a real player.
  - `ShiftService.luau`: `QuestService:AdvanceQuest(player, "ShiftsCompleted", 1)` when a shift is completed.
  - (`OrderService.luau` already wires `QuestService:AdvanceQuest(player, "BobaOrdered", 1)`).
- `QuestService.spec.luau`:
  - TestEZ test suite covering:
    - Day transition and fresh daily quest generation.
    - Same-day retrieval idempotency.
    - Type-specific progress advancement and target clamping.
    - Reward claiming with BobaBucks & XP grant, and double-claim idempotency rejection.
    - Star Employee (219650999) +1 slot expansion and free reroll grant & consumption.
    - More Quests (12385834) +1 slot expansion.
    - Paid reroll costing 50 BobaBucks and insufficient funds rejection.
