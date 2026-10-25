# M4-TREASURE-CHESTS: Hidden Treasure Chests & Exploration Loop
Model: sonnet / spark   Studio: no   Depends on: none   Size: M

## Goal
Implement the Hidden Treasure Chests system (revival-plan §4.7):
- Reuses `Workspace.OldScriptables.ChestNodesFolder` (15 authored node locations in the place file).
- Spawns interactive chests with `ProximityPrompt` at unoccupied nodes.
- Grants random BobaBucks (35–100) and a chance for a Pet Capsule.
- Increments `ProfileTemplate.Statistics.TreasureChestsFound` stat.
- Awards badge `2124774045` ("Treasure Chest!") via `BadgeService`.
- Bounded respawn scheduler and unit tests.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `src/shared/Utility/WorldPath.luau`
- `src/shared/Configuration/ProfileTemplate.luau` (Statistics.TreasureChestsFound)
- `src/server/Modules/CurrencyService.luau` (Modify method)
- `src/shared/Inventory/InventoryServer.luau` (AddItem method)
- `src/server/Modules/StatisticsService.luau` (IncrementStat method)
- `src/server/Modules/BadgeService.luau` (AwardBadge, TreasureChest = 2124774045)

## Write scope
- `src/shared/Configuration/TreasureHuntConfig.luau` (new)
- `src/server/Modules/TreasureHuntService.luau` (new)
- `src/server/Tests/TreasureHuntService.spec.luau` (new)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-TREASURE-CHESTS/evidence.md` (new)

## Steps
1. Create `src/shared/Configuration/TreasureHuntConfig.luau`:
   - `MAX_ACTIVE_CHESTS = 5` (number of chests active at any one time)
   - `RESPAWN_DELAY_SECONDS = 90` (time before a collected chest spawns at a new free node)
   - `MIN_BOBABUCKS = 35`
   - `MAX_BOBABUCKS = 100`
   - `CAPSULE_CHANCE = 0.15` (15% chance to award a "Regular Pet Capsule" or "Nametag Capsule")
   - `PROMPT_HOLD_DURATION = 1.0`
   - `PROMPT_MAX_DISTANCE = 10`
   - `BADGE_ID = 2124774045`
   - Pure helper `TreasureHuntConfig.RollReward(randomSource: Random?): { BobaBucks: number, Capsule: string? }`:
     - Rolls BobaBucks between `MIN_BOBABUCKS` and `MAX_BOBABUCKS`.
     - Rolls random float; if <= `CAPSULE_CHANCE`, rolls between `"Regular Pet Capsule"` and `"Nametag Capsule"`.
2. Create `src/server/Modules/TreasureHuntService.luau`:
   - Knit service named `"TreasureHuntService"`.
   - In `KnitStart`:
     - Resolves `Workspace.OldScriptables.ChestNodesFolder` (or `workspace.Assets.Chests`) using `WorldPath.find` or `WorldPath.waitFor` (bounded 10s wait). If not found, logs a warning and disables spawning cleanly (continued-play rule).
     - Gathers the 15 node BaseParts.
     - Spawns initial batch up to `MAX_ACTIVE_CHESTS`.
   - Node & Chest Spawning logic:
     - Maintains a set of occupied nodes.
     - Spawns a chest model/part at a random unoccupied node:
       - Visual: Anchored Part or Model sized to fit the node (e.g. Size 3.5, 2.5, 2.5, Color3 warm brown/gold, Material SmoothPlastic / Metal).
       - Adds a `ProximityPrompt`: ObjectText = "Treasure Chest", ActionText = "Open", HoldDuration = 1.0, MaxActivationDistance = 10.
       - Marks node's `Occupied` BoolValue (if present) to `true`.
   - Chest interaction handler:
     - When prompt is triggered by `player: Player`:
       - Distance check: verify player character is within `PROMPT_MAX_DISTANCE + 5` studs.
       - Calculate reward via `TreasureHuntConfig.RollReward()`.
       - Award BobaBucks via `CurrencyService:Modify(player, "BobaBucks", reward.BobaBucks, "TreasureChest")`.
       - If reward has Capsule, award via `InventoryServer:AddItem(player, "Capsules", reward.Capsule)`.
       - Increment stat: `StatisticsService:IncrementStat(player, "TreasureChestsFound", 1)`.
       - Award badge: `BadgeService:AwardBadge(player, TreasureHuntConfig.BADGE_ID)`.
       - Destroy chest instance.
       - Mark node unoccupied.
       - Schedule respawn after `RESPAWN_DELAY_SECONDS`.
3. Create `src/server/Tests/TreasureHuntService.spec.luau`:
   - TestEZ spec covering:
     - Pure reward roller: BobaBucks bounds and capsule drop logic.
     - Node selection: respects occupied state and node capacity.
     - Distance validation: rejects triggers from out-of-range positions.
4. Run WSL gate and verify clean output.

## Done when
- `TreasureHuntConfig.luau` exports chest tuning and reward roller.
- `TreasureHuntService.luau` starts cleanly, binds to chest nodes, and handles claims.
- `TreasureHuntService.spec.luau` passes.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/TreasureHuntConfig.luau src/server/Modules/TreasureHuntService.luau src/server/Tests/TreasureHuntService.spec.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-TREASURE-CHESTS/evidence.md`
