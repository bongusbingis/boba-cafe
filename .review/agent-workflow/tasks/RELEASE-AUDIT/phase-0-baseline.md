# Phase 0 Baseline — Release Audit (2026-10-24)

## SOURCE SHA
`5afa32f28c6d48073dae15ec7ee2e2175c12a64c`

## UNCOMMITTED PATHS (9 files)
- `src/server/Modules/BobaBuddyService/FollowBehavior.luau` (+25/-5 lines)
- `src/server/Modules/BobaBuddyService/Navigator.luau` (+12/-1 lines)
- `src/server/Modules/BobaBuddyService/init.luau` (+20/-7 lines)
- `src/server/Modules/DataService/init.luau` (+2/-2 lines) — **CRITICAL BLOCKER DETECTED**: `IS_MOCK_STORE_ENABLED = true`
- `src/server/Modules/StarterBundleReceipts.luau` (+3/-0 lines)
- `src/server/Tests/StarterBundleReceipts.spec.luau` (+12/-0 lines)
- `src/shared/Configuration/SeasonConfig.luau` (+4/-2 lines) — `SEASON_1_START_EPOCH` shifted to 1792828800
- `src/shared/UI/Pages/Shop/Featured.luau` (+36/-8 lines) — Starter Bundle claimed status UI handling
- `src/shared/UI/Pages/Shop/Products.luau` (+2/-2 lines) — Starter price string formatting

## TOP 25 RECENTLY MODIFIED FILES (Last 14 Days)
1. `src/server/Modules/SpillService/Spill.luau`
2. `src/shared/UI/Pages/Shop/Products.luau`
3. `src/server/Cmdr/Commands/Events/SpawnSpillServer.luau`
4. `src/server/Cmdr/Commands/Events/SpawnSpill.luau`
5. `src/server/Cmdr/Types/SpillTemplate.luau`
6. `src/server/Modules/BobaBuddyService/FollowBehavior.luau`
7. `src/server/Modules/BobaBuddyService/Navigator.luau`
8. `src/server/Modules/BobaBuddyService/init.luau`
9. `src/shared/Configuration/SeasonConfig.luau`
10. `src/server/Tests/StarterBundleReceipts.spec.luau`
11. `src/server/Modules/StarterBundleReceipts.luau`
12. `src/shared/UI/Pages/Shop/Featured.luau`
13. `src/server/Modules/DataService/init.luau`
14. `src/shared/Configuration/GroupRankProgression.luau`
15. `src/server/Tests/GroupRankProgression.spec.luau`
16. `src/shared/UI/Pages/Menu/Staff.luau`
17. `src/server/Tests/SeasonPass.spec.luau`
18. `src/shared/UI/Pages/Shop/init.luau`
19. `src/server/Modules/SeasonPassService.luau`
20. `src/server/Scripts/ProcessReceipt.server.luau`
21. `src/shared/UI/Pages/Shop/Season.luau`
22. `src/shared/UI/Pages/Recipes/init.luau`
23. `src/shared/UI/Pages/Menu/Settings.luau`
24. `src/shared/UI/Pages/Menu/Purchases.luau`
25. `src/shared/UI/Pages/Menu/PromoCodes.luau`

## GATE RESULT
`scripts/gate.sh`: **PASS**
- Selene: 0 new findings (baseline preserved)
- StyLua: Clean formatting across all files
- Rojo build: Built successfully to `/tmp/gate-build.rbxl`

## TESTS STATUS
- `TESTS_ENABLED = false` in `src/server/Tests/RunTests.server.luau`.
- **TESTS NOT RUN — Jack must flip and run TestEZ before publish.**
- Last recorded suite run in `.review/agent-workflow/tasks/PRE-RELEASE-REVIEW/review.md`: **988 passed, 20 failed** (failures were mock GiveTool test harness issues and stale ShiftService spec).

## STUDIO STATE
- Studio 1: `d9ef10b5-a3c1-486c-aa72-7e3693fbc323` (Boba Cafe 🍵, placeId: 718328620) — Mode: Edit
- Studio 2: `b923404e-2d11-40a5-8641-4d7dd186a729` (beta, placeId: 128511401637461) — Mode: Edit
- **STUDIO: busy — Play skipped per Jack.**

## DOC-CLAIM DISPROOFS
1. `SYSTEMS.md` line 48: Claims *"Nothing in src/ calls TrySpendAsync yet"*.
   - **Disproved**: Called directly by `CafeUpgradeService/init.luau`, `CapsuleService.luau` (4 call sites), and `QuestService.luau` (rerolls).
2. `SYSTEMS.md` line 49: Claims *"TreasureChestsFound exists in the template and the Statistics page, but nothing in src/ increments them yet"*.
   - **Disproved**: `TreasureHuntService.luau` explicitly calls `statisticsService:IncrementStat(player, "TreasureChestsFound", 1)`.
3. `SYSTEMS.md` line 7: Claims working tree is on *"HEAD 92f6144 as read on 2026-10-14"*.
   - **Disproved**: HEAD is `5afa32f` with 10 days of heavy commits; documents are severely stale.
4. `ARCHITECTURE.md` Section 3: Lists Knit services and shared configs, but completely omits 20+ core services (e.g. `SeasonPassService`, `StarterBundleReceipts`, `BobaBuddyService`, `CafeUpgradeService`, `CharacterCustomizationService`, `PassSettingsService`, `PassToolService`, `RankingService`) and major configs (`SeasonConfig`, `ProductIds`, `BobaBuddyConfig`).
