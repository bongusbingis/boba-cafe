# M3-REM-B: Pass perk catalog and resolver (E20), XP/tip boosts (E20, E21)
Model: sonnet   Studio: no   Depends on: M4-FIXES, M3-REM-A   Size: M

## Goal
Owners of the approved passes get their perks through one catalog and one resolver, and equipped pets add the approved tip boost.

## Already built (verified)
- Nothing for the catalog: no `PassCatalog`, `Perks` or `PerkService` exists (grep over `src/`). Pass data is `src/shared/Configuration/Gamepasses.luau:7-65` (11 passes) plus More Quests injected at `QuestService.luau:18-25`.
- Perks already working by hard-coded pass id, leave them as they are: VIP 2x daily (`DailyRewardService.luau:160`, `DailyRewardConfig.luau:19-20`); +1 quest slot and free reroll (`QuestConfig.luau:17-18`, `QuestService.luau:84-92`); Instant Brew hold 0.5 s (`KitchenController.luau:21-22,44-53`).
- Pet tier is available per equipped pet: `PetService.luau:34-57` (`equippedPetsByUserId`, field `Tier`). No server getter exists for it.
- There is NO tip mechanic in the current loop (`ShiftService.luau:184` hard-codes `Tips = 0`; `CustomerService/init.luau:727-732` pays one amount). Tip-family boosts (E20 Barista/Kitchen Leader, E21 pets) have nothing to multiply until Jack answers Q1 below.

## Note on M4-FIXES
`packets/M4-FIXES.md` runs first and touches CurrencyService, RealOrderService, CustomerService/init.luau, LeaderboardService, TreasureHuntService, BadgeService, DailyRewardsDialog. Do not edit those files in steps 1-5. Step 6 (only after Q1 is answered) edits the pay lines in CustomerService/init.luau and RealOrderService: re-read their post-M4-FIXES text first and edit by function name, not line number.

## Read (only these)
- `docs/SYSTEMS.md` and `docs/CONVENTIONS.md`: only the service/Knit and config sections
- `revival-plan.md` §6.3 (lines 348-384); `M3-ECON/answers.md` Batch 4 (E20, E21)
- `src/shared/Utility/GamepassUtil.luau:111-153`
- `src/shared/Configuration/Gamepasses.luau`
- `src/server/Modules/PetService.luau:16-60`
- `src/server/Modules/ProgressionService.luau:44-70`
- `src/shared/Configuration/PetConfig.luau`: tier names

## Write scope
- `src/shared/Configuration/PassCatalog.luau` (new)
- `src/shared/Configuration/Perks.luau` (new)
- `src/server/Modules/PerkService.luau` (new)
- `src/server/Modules/PetService.luau` (add `GetBestTipTier`)
- `src/server/Modules/ProgressionService.luau` (XP perk in `AddXp` only)
- `src/server/Tests/PerkService.spec.luau` (new)
- After Q1 only: `src/server/Modules/CustomerService/init.luau`, `src/server/Modules/RealOrderService.luau`

## Steps
1. New `PassCatalog.luau` per revival-plan §6.3: `[passId] = { Name, Perks = {string}, Listed = boolean, Legacy = boolean }`. Include only approved defined mappings (DEC-028 E20):
   - Barista 6202153 and Senior Barista 6202144: `TipBoost25`, `XpBoost25`.
   - Kitchen Leader 15243046 and Staff Assistant 6202139: `TipBoost50`, `XpBoost50`.
   - VIP 12385781 and Premium Lounge 2126368: perk names `DailyReward2x` (VIP only), `VipLounge`.
   - Star Employee 219650999: `QuestSlot`, `QuestReroll`. More Quests 12385834: `QuestSlot`.
   - Instant Brewing 12385760: `StationHold50`. Faster Walk Speed 12385742: `WalkSpeed`.
   - Double Storage 14067346: `InventoryX2`.
   - `Listed` = true only for the on-sale rows in §6.3 (Barista, Kitchen Leader, VIP, Star Employee, Instant Brewing, Faster Walk Speed); `Legacy` = true for the off-sale rows.
   - Do NOT add x2/x4 Multiplier, Unlock All Pets or Unlimited Stock (deferred, DEC-028). Do not add cosmetic, tool, water-area or title rows in this packet.
2. New `Perks.luau`: `TipBoost = { Barista = 0.25, KitchenLeader = 0.50 }` style data keyed by perk name: `TipBoost25 = {Family="Tip", Value=0.25}`, `TipBoost50 = {Family="Tip", Value=0.50}`, `XpBoost25 = {Family="Xp", Value=0.25}`, `XpBoost50 = {Family="Xp", Value=0.50}`. Values: revival-plan §6.3 via DEC-028. Stacking rule: highest value per Family wins, no adding (§6.3 lines 357).
3. New `PerkService.luau` (Knit service, follow an existing service's shape, e.g. `PetService.luau`): `HasPerk(player, perk)` resolves through `GamepassUtil:PlayerOwnsPassAsync` for every passId whose catalog row lists the perk; owners get perks whether `Listed` or not. `GetFamilyBonus(player, family)` returns the highest `Value` of owned perks in that family, else 0.
4. `PetService.luau`: add `PetService:GetBestTipBonus(player)` returning the highest tier bonus among equipped pets from `equippedPetsByUserId`: Basic 0.02, Rare 0.04, Epic 0.07, Legendary 0.10 (DEC-028 E21). Put the table in `Perks.luau` as `PetTipBonus`. Unknown tier returns 0.
5. `ProgressionService.AddXp`: multiply `amount` by `1 + PerkService:GetFamilyBonus(player, "Xp")` (round) before use. Do not apply to `skipShiftCount` calls until Q2 is answered.
6. Tip boost wiring: only after Q1 is answered. Combine pass and pet via `1 + max(passTipBonus, petTipBonus)` (highest-wins in the tip family, proposal S15/S17), unless Q3 answer says otherwise.
7. Spec `PerkService.spec.luau`: highest-wins stacking, unlisted-owner still gets perk, deferred passes absent from the catalog, pet tier table values, unknown tier = 0. Mock `GamepassUtil` the way `QuestService.spec.luau:312` does.
8. Run the gate.

## Done when
- `PassCatalog.luau` has no x2/x4, Unlock All Pets or Unlimited Stock rows.
- `PerkService:GetFamilyBonus` returns the max, not the sum (spec proves it).
- Pet bonuses are exactly 0.02/0.04/0.07/0.10.
- XP perk multiplies serve XP (spec).
- Existing DailyReward, Quest and Instant Brew behaviour is unchanged (their specs pass).

## Checks to run
- `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. Never Play or run TestEZ (DEC-019); add a "Test for Jack" list to evidence.

## STOP-AND-ASK
- none: B1-B4 are answered in DEC-036: B1=A (boost multiplies each serve's BB pay, NPC and real; the shift summary Tips line shows the boost-earned extra), B2=A (all play XP), B3=A (highest in a family wins), B4=A (Double Storage moves to M3-REM-D; skip it here). Apply them where the packet asked.
Evidence
`tasks/REVIVAL-001/M3-REM-B/evidence.md` (RUNBOOK step 5)
