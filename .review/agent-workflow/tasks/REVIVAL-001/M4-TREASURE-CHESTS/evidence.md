RESULT: PASS
Files changed:
- src/shared/Configuration/TreasureHuntConfig.luau
- src/server/Modules/TreasureHuntService.luau
- src/server/Tests/TreasureHuntService.spec.luau

Gate check output:
```
PASS  src/shared/Configuration/TreasureHuntConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/TreasureHuntService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/TreasureHuntService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `TreasureHuntConfig.luau`: Configures MAX_ACTIVE_CHESTS (5), RESPAWN_DELAY_SECONDS (90), MIN_BOBABUCKS (35), MAX_BOBABUCKS (100), CAPSULE_CHANCE (0.15), PROMPT_HOLD_DURATION (1.0), PROMPT_MAX_DISTANCE (10), BADGE_ID (2124774045). Implements pure helper `RollReward(randomSource?)` returning BobaBucks in [35, 100] and rolling a 15% chance for either "Regular Pet Capsule" or "Nametag Capsule".
- `TreasureHuntService.luau`: Knit Service that resolves `Workspace.OldScriptables.ChestNodesFolder` (or fallback `Workspace.Assets.Chests`) in KnitStart using bounded `WorldPath.find` and `WorldPath.waitFor` (up to 10s total). Follows continued-play rule by logging a warning and disabling cleanly if nodes are missing. Spawns up to MAX_ACTIVE_CHESTS (5) at unoccupied nodes, marks `Occupied` BoolValue on nodes, attaches a ProximityPrompt ("Treasure Chest" / "Open", hold 1.0s, max distance 10 studs, tagged `BuiltBy = "REVIVAL-001-CHESTS"`). On interaction: verifies player character distance within 15 studs (PROMPT_MAX_DISTANCE + 5), prevents duplicate claims, rolls reward, modifies BobaBucks via `CurrencyService:Modify(player, "BobaBucks", reward.BobaBucks, "TreasureChest")`, awards capsule (if rolled) via `InventoryServer:AddItem(player, "Capsules", reward.Capsule)` (with robust fallback on InventoryServer), increments stat `TreasureChestsFound` via `StatisticsService:IncrementStat(player, "TreasureChestsFound", 1)`, awards badge 2124774045 via `BadgeService:AwardBadge(player, BADGE_ID)`, destroys the chest instance, marks the node unoccupied, and schedules respawn after RESPAWN_DELAY_SECONDS (90s).
- `TreasureHuntService.spec.luau`: Full TestEZ unit tests covering reward roller bounds and capsule drops, node selection with occupied state and capacity enforcement, and distance validation with successful reward/stat/badge dispatches.
