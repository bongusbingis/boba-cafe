---
id: BIG-B1-P2-POOL
title: B1 phase 2 - L2 Taro Boba and Strawberry Boba join the NPC order pool from MIN_LEVEL_BY_ITEM
priority: P0
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [BIG-B1-P1-AUDIT, PATIENCE-RAMP, GAMEPLAY-PROGRESS-CALLOUTS]
status: READY
source_commit: 098175c
read_scope:
  - src/shared/Configuration/Progression.luau (MIN_LEVEL_BY_ITEM)
  - src/shared/Configuration/CustomerConfig.luau (PoolEntry, ORDER_POOL)
  - src/server/Modules/CustomerService/Rules.luau (PickOrder, pickIndex)
  - src/server/Modules/ProgressionService.luau (unlocksAt and _onLevelUp as left by GAMEPLAY-PROGRESS-CALLOUTS)
  - src/server/Tests/CustomerService.spec.luau
write_scope:
  - src/shared/Configuration/CustomerConfig.luau (PoolEntry type, ORDER_POOL, two new constants)
  - src/server/Modules/CustomerService/Rules.luau (new Rules.NewDrinksAt only)
  - src/server/Modules/ProgressionService.luau (unlocksAt first entry, one require)
  - src/server/Tests/CustomerService.spec.luau (new cases appended inside the existing describe blocks)
invariants:
  - serve-path no-yield (WORKER-PRIMER 1): this packet adds no code to CustomerService/init.luau or RealOrderService; PickOrder stays pure and non-yielding; QuestService:AdvanceQuest can yield and is not touched
  - DEC-008: only the two drinks BIG-B1-P1-AUDIT marks VERIFIED-IN-SOURCE are added; Hot Cocoa Classic and Strawberry Tapioca get no pool entry, no data, no flag
  - Progression.MIN_LEVEL_BY_ITEM values and PAY_TABLE are read, never edited
  - existing PickOrder expectations at level 1 keep passing unchanged (classic entries stay first, in today's order)
acceptance:
  - ORDER_POOL has 5 entries; entries 1-3 are today's three with Key/Label added; 4 = Taro Boba, 5 = Strawberry Boba
  - every entry's MinLevel equals Progression.MIN_LEVEL_BY_ITEM[entry.Key] (read at require time, not copied)
  - PickOrder at level 1 never returns a Taro or Strawberry syrup; at level 2 it can return both
  - Rules.NewDrinksAt(2) returns { "Taro Boba", "Strawberry Boba" }; level 1 and 3 return {}
  - the level-2 toast text equals the string in section 3
  - gate passes with no new findings in the four files
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/CustomerConfig.luau src/server/Modules/CustomerService/Rules.luau src/server/Modules/ProgressionService.luau src/server/Tests/CustomerService.spec.luau'"
  - rojo build default.project.json -o <scratchpad>/b1p2.rbxl
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P2-POOL
forbidden: [WORKER-PRIMER 8, editing MIN_LEVEL_BY_ITEM or PAY_TABLE, editing Menu.luau, adding any pool entry not in section 4, a Confirmed/disabled flag or gated entry, editing CustomerService/init.luau, changing existing spec expectations]
---

Worker rules: `_meta/WORKER-PRIMER.md`. Design: `packets/BIG-B1.md`. Source commit 098175c.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- P5: What: Menu grows with level (wire MIN_LEVEL_BY_ITEM). Why: Real payoff per level; variety beats boredom. Big bet B1. Files: CustomerConfig.ORDER_POOL, Menu.LAUNCH_ITEMS. Effort: M-L. Risk: Med. Tag: JACK (Q-G1).
- B1 Rough plan (2): Mason: ORDER_POOL entries with MinLevel from MIN_LEVEL_BY_ITEM; LAUNCH_ITEMS updated; specs for PickOrder by level. (3) The P1 callout names the new drink.
- Jack (DEC-054 Q-G1): start with L2 Taro and Strawberry syrup, L3 Hot Cocoa Classic, L4 Strawberry tapioca, each only after a working end-to-end recipe.

## 2. Decisions made
- D1 This pack is Taro Boba and Strawberry Boba at Level 2 only. Rationale: they are the Q-G1 drinks BIG-B1-P1-AUDIT verifies end to end in source (code-spawned syrup dispenser plus the live Classic Milk Tea chain); Hot Cocoa Classic and Strawberry Tapioca need authored stations and wait for Jack (Open items). This supersedes BIG-B1 D1/D2/D8 (no gated data, no `Confirmed` flag, Espresso and Mango not in this pack).
- D2 Level ladder for this pack: L1 Classic Milk Tea Boba, Regular Coffee, Fudge Brownie; L2 Taro Boba, Strawberry Boba. Later rungs are added by a follow-up packet after Jack answers the Open items. Rationale: MIN_LEVEL_BY_ITEM is the single source; nothing unverified enters the ladder.
- D3 Names (player-facing `Label`): `Taro Boba`, `Strawberry Boba`; the three classics get `Classic Milk Tea Boba`, `Regular Coffee`, `Fudge Brownie`. `Key` is the MIN_LEVEL_BY_ITEM key. Rationale: flavour + "Boba" is what players call the drink, and each name fits one Recipe Book line at 844x390.
- D4 `MinLevel = Progression.MIN_LEVEL_BY_ITEM[<Key>]` for all five entries; `CustomerConfig` requires `script.Parent.Progression` (precedent: `QuestConfig.luau` requires `script.Parent.ProfileTemplate`). Rationale: no duplicated numbers.
- D5 Weights: Taro 10, Strawberry 10 (PROPOSED). Classics keep 55/30/15. Rationale: each new drink is about 1 in 12 orders at L2 (8.3%), enough to notice and learn; classics keep 83.3%.
- D6 Guard constants `CLASSIC_MIN_SHARE = 0.6` and `NEW_ENTRY_MAX_WEIGHT = 10` (TUNING) are tested at every level 1..MAX_LEVEL so future packs cannot drown the classics.
- D7 Pay and patience use existing `PAY_TABLE["Boba Teas"] = 3` and `PATIENCE_BONUS_SECONDS["Boba Teas"]`; no new key. Average base pay per item moves only from mix (2.40 at L1 to 2.50 at L2).
- D8 `Rules.PickOrder` code is unchanged: its MinLevel filter and fallback already do the job, and every entry is enabled.
- D9 Level-up copy: `unlocksAt(level)` puts the new-drinks text FIRST, so `_onLevelUp` (first two entries) and `nextUnlock` (first entry) name the drinks.
- D10 Menu.luau is not edited: `LAUNCH_ITEMS["Boba Teas"]` has `Custom Boba` and `LAUNCH_CHOICES["Syrup Flavor"]` has `Taro` and `Strawberry` (verified at 098175c); the existing "keep pool entry on the launch menu" case covers the new entries.

## 3. Exact strings
- Labels: `Classic Milk Tea Boba`, `Regular Coffee`, `Fudge Brownie`, `Taro Boba`, `Strawberry Boba`.
- unlocksAt entry: one drink `New drink: {A}`; two or more `New drinks: {A}, {B}` (labels joined with `, `).
- L2 toast: `Level up! You are now level 2 · New drinks: Taro Boba, Strawberry Boba`
- ShiftCard next line at L1 (GAMEPLAY-PROGRESS-CALLOUTS nextUnlock, no code change): `Level 2 · New drinks: Taro Boba, Strawberry Boba`

## 4. Exact numbers and pool (append after the Fudge Brownie entry)
| # | Key | Label | Category / Item | CustomInfo | Sized | Weight |
|---|---|---|---|---|---|---|
| 1 | Classic Milk Tea Boba | Classic Milk Tea Boba | Boba Teas / Custom Boba | unchanged | true | 55 |
| 2 | Regular Coffee | Regular Coffee | Coffees / Regular | unchanged | true | 30 |
| 3 | Fudge Brownie | Fudge Brownie | Pastries / Fudge Brownie | unchanged | false | 15 |
| 4 | Taro Syrup | Taro Boba | Boba Teas / Custom Boba | `["Syrup Flavor"] = "Taro", ["Tapioca Flavor"] = "Normal"` | true | 10 -- PROPOSED (Jack) |
| 5 | Strawberry Syrup | Strawberry Boba | Boba Teas / Custom Boba | `["Syrup Flavor"] = "Strawberry", ["Tapioca Flavor"] = "Normal"` | true | 10 -- PROPOSED (Jack) |
- Each entry's `MinLevel` line becomes `MinLevel = Progression.MIN_LEVEL_BY_ITEM["<Key>"], -- PROPOSED (Jack) via Progression`.
- New top-level constants after `ORDER_POOL`: `CLASSIC_MIN_SHARE = 0.6, -- TUNING` and `NEW_ENTRY_MAX_WEIGHT = 10, -- TUNING`.
- Pick bands at level 2 (total 120): Classic [0, 0.4583), Coffee [0.4583, 0.7083), Brownie [0.7083, 0.8333), Taro [0.8333, 0.9167), Strawberry [0.9167, 1).
- Ledger rows added to `_meta/ECONOMY-LEDGER.md` for both weights.

## 5. Signatures and event names
- `export type PoolEntry = { Key: string, Label: string, Weight: number, MinLevel: number, Sized: boolean, OrderItem: OrderItem }`
- `function Rules.NewDrinksAt(level: number, config: Config?): { string }` - Labels of `ORDER_POOL` entries with `MinLevel == level`, in pool order; `{}` when `level <= 1`. Place it after `Rules.ItemCountForLevel`.
- ProgressionService: add `local Rules = require(script.Parent.CustomerService.Rules)` under the existing requires. In `unlocksAt(level)` first line: `local drinks = Rules.NewDrinksAt(level)`; if `#drinks == 1` insert `New drink: {drinks[1]}`, if `#drinks > 1` insert `New drinks: {table.concat(drinks, ", ")}`, as entry 1, before the title entry.
- No remote, attribute or profile field.

## 6. Spec cases (append; existing cases untouched)
In `describe("PickOrder (design 4.4)")`:
- `should never pick a level-2 drink at level 1`: for r = 0, 0.99 step 0.01, `Rules.PickOrder(sequence({ r, 0 }), nil, 1).CustomInfo["Syrup Flavor"]` is nil or `"Classic Milk Tea"`, never `"Taro"` or `"Strawberry"`.
- `should pick Taro Boba at level 2`: `sequence({ 0.85, 0 })`, level 2 -> Item `Custom Boba`, Syrup Flavor `Taro`, Tapioca Flavor `Normal`, Size `Small`.
- `should pick Strawberry Boba at level 2`: `sequence({ 0.95, 0 })`, level 2 -> Syrup Flavor `Strawberry`.
- `should keep the classic picks at level 2`: `sequence({ 0.5, 0 })`, level 2 -> Item `Regular`.
New `describe("ORDER_POOL level ladder (B1)")`:
- every entry has a non-empty `Key` and `Label`, Keys are unique, and `entry.MinLevel == Progression.MIN_LEVEL_BY_ITEM[entry.Key]`.
- for level = 1..Progression.MAX_LEVEL: (sum of eligible MinLevel-1 weights) / (sum of eligible weights) >= `CLASSIC_MIN_SHARE`.
- every entry with `MinLevel > 1` has `Weight <= NEW_ENTRY_MAX_WEIGHT`.
- `Rules.NewDrinksAt(1)` and `(3)` are empty; `(2)` equals `{ "Taro Boba", "Strawberry Boba" }`.
- Add `local Progression = require(ReplicatedStorage.Shared.Configuration.Progression)` at the top of the spec.

## 7. UI spec
- None in this phase (Recipe Book is BIG-B1-P3-RECIPEBOOK).

## 8. Studio checks (Jack; one milestone run)
- S-P2-1: Level 1 profile, clock in, serve 20 NPCs. Expected: no ticket shows Taro or Strawberry; no red error.
- S-P2-2: Reach Level 2. Expected toast: `Level up! You are now level 2 · New drinks: Taro Boba, Strawberry Boba`.
- S-P2-3: At Level 2 serve until a Taro order appears (about 1 in 12). Expected: lilac NPC chip; Small/Medium/Large Clear Cup -> Milk -> Taro Syrup -> Normal Tapioca serves Perfect and pays like Classic.
- S-P2-4: Same for Strawberry. Expected: pink chip; Strawberry Syrup chain serves Perfect.
- S-P2-5: Run the TestEZ CustomerService spec; all old and new cases pass.

## 9. Asset prerequisites
- None beyond the live chain: `workspace.Assets.Kitchen.Syrups` area, `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser` (spawns `Taro Syrup`, `Strawberry Syrup` via `KitchenService:_spawnSyrupDispensers`), Kitchen `Clear Cup`, `Milk`, `Normal Tapioca`. If the Syrups area is missing KitchenService already warns once and no dispenser spawns; the order still resolves (no error).

Open items:
- HARD-STOP 1: Do `workspace.Assets.Kitchen.Mug`, `workspace.Assets.Kitchen["Hot Chocolate Powder"]` and Tool `ReplicatedStorage.SharedStorage.Tools.Kitchen.Mug` exist and make a Hot Chocolate end to end (P1-AUDIT S1, yes/no). Yes -> follow-up packet adds `Hot Cocoa Classic` (L3, Label `Hot Chocolate`, Sized false, CustomInfo Size `Mug`, weight 10 PROPOSED).
- HARD-STOP 1: Does `workspace.Assets.Kitchen["Strawberry Tapioca"]` exist and finish a Classic Milk Tea boba with Strawberry pearls (P1-AUDIT S2, yes/no). Yes -> follow-up adds `Strawberry Tapioca` (L4, Label `Strawberry Pearl Boba`, weight 8 PROPOSED).
- SCOPE (Jack, yes/no): Espresso (L7) and Mango Syrup (L8) are VERIFIED-IN-SOURCE but outside the Q-G1 start list; add them in the follow-up pack.
- LEASE: INVENTORY's "BIG-B1" on CustomerConfig/Rules/ProgressionService/spec reads as BIG-B1-P2-POOL.

## Summary
- Wires Progression.MIN_LEVEL_BY_ITEM into ORDER_POOL; adds Taro Boba and Strawberry Boba at Level 2 (weights 10/10 PROPOSED).
- Only audit-verified drinks; Hot Chocolate and Strawberry Pearl Boba get no code until Jack answers S1/S2.
- PickOrder untouched; new Rules.NewDrinksAt feeds the level-up toast and ShiftCard next line.
- Classics keep >= 60% at every level (tested); existing pay and patience categories only.
- Menu.luau unchanged; existing spec cases unchanged.
