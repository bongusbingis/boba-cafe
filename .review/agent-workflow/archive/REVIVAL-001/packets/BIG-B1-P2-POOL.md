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

## Extension: Espresso L7 + Mango L8

Approval: Jack, 2026-10-20 ("3. yes": Espresso (L7) and Mango (L8) join B1 phase 1; recorded in DEC-057). For these two entries only, this section supersedes D1/D2, the forbidden item "adding any pool entry not in section 4", and the Open item "SCOPE ... Espresso (L7) and Mango Syrup (L8)". Hot Cocoa Classic (L3) and Strawberry Tapioca (L4) stay OUT (no entry, no data, no flag) until Jack answers the two HARD-STOP 1 items above.

Source for this extension: HEAD after ee9a515 (P2 landed as a6bc551, P3 as ee9a515). Builder tier: sonnet. Evidence: `.review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P2-POOL/ext-espresso-mango/` (gate.txt, summary.md). Do the P3 extension (`BIG-B1-P3-RECIPEBOOK.md`, "Extension") in the same run; its spec change fails without this one.

### E1. How Taro/Strawberry were wired (verified in `git show a6bc551`)
- `CustomerConfig.luau`: two entries were appended after Fudge Brownie in `ORDER_POOL`, each shaped `{ Key, Label, Weight = 10, -- PROPOSED (Jack): <Label>`, `MinLevel = Progression.MIN_LEVEL_BY_ITEM["<Key>"], -- PROPOSED (Jack) via Progression`, `Sized = true, OrderItem = { Category, Item, CustomInfo } }`.
- `Rules.NewDrinksAt` returns the Labels of entries with `MinLevel == level`. `ProgressionService.unlocksAt` already puts `New drink: X` / `New drinks: X, Y` first. Both read the pool, so **no code change** is needed in `Rules.luau` or `ProgressionService.luau` for new entries.
- `PickOrder` is unchanged. Its MinLevel filter covers the new entries.

### E2. Source verification at HEAD (both VERIFIED-IN-SOURCE; nothing BLOCKED)
| Drink | Check | File:symbol (quoted) |
|---|---|---|
| Espresso | level | `Progression.luau` MIN_LEVEL_BY_ITEM `["Espresso"] = 7,` |
| Espresso | menu item, sized, Iced/Sugar options | `Menu.luau` `COFFEE_NAMES` has `"Espresso"`; `buildCoffeeItems` -> `buildCupItem(coffeeName, DEFAULT_CUP_MODEL, SIZE_SMALL_MEDIUM_LARGE, { Options = COFFEE_OPTIONS })`; `COFFEE_OPTIONS = { ["Iced"] = false, ["Sugar"] = false }` |
| Espresso | launch menu | `LAUNCH_ITEMS["Coffees"] = { "Regular", "Espresso", ... }` |
| Espresso | station + branch | `Recipes.luau` `["Coffee Machine"]` Buttons `{ Text = "Espresso" }`, Items `{ Name = "Espresso", ModelName = "Medium Cup" }`, branch `["Espresso"] = makeCoffeeVariant("Espresso", Color3.fromRGB(217, 137, 87))`; `makeCoffeeVariant` sets `{ Item = name }` |
| Espresso | cup giver | `Recipes.Items["Cup"] = makeCupGiver("Cup")` (tools `Cups.<Size> Cup`), the same one Regular Coffee uses |
| Espresso | order chain | `OrderSpec.buildStages` coffee branch: `cupStage("Cup", size, true)` then `{ Station = "Coffee Machine", Choice = spec.Item, Label = spec.Item }` -> steps `<Size> Cup`, `Espresso` |
| Espresso | pay / patience | `PAY_TABLE["Coffees"] = 2`; `PATIENCE_BONUS_SECONDS["Coffees"]` (existing, same as Regular Coffee) |
| Mango | level | `["Mango Syrup"] = 8,` |
| Mango | flavour + launch | `Menu.luau` `SyrupFlavor["Mango"]` (255,192,92); `LAUNCH_CHOICES["Syrup Flavor"]` has `"Mango"` |
| Mango | station | `Recipes.Syrups["Mango"] = Color3.fromRGB(255, 192, 92)`; syrup loop `Recipes.Items[name .. " Syrup"]`; `KitchenService:_spawnSyrupDispensers` `syrupDispenser.Name = name .. " Syrup"` (Mango Syrup already spawns today) |
| Mango | order chain | `OrderSpec.buildStages` boba branch: `<Size> Clear Cup`, `Milk`, `Mango Syrup`, `Normal Tapioca` |
| Mango | chip | `Npc.luau chipColor` -> `Recipes.Syrups["Mango"]` (orange) |
| Mango | pay / patience | `PAY_TABLE["Boba Teas"] = 3`; `PATIENCE_BONUS_SECONDS["Boba Teas"] = 25` |

Neither drink needs a new price, reward, patience or XP value. Both use only stations a live L1 chain already uses: Espresso uses Regular Coffee's `Cup` and `Coffee Machine`, and Mango uses Taro's chain with a code-spawned dispenser.

### E3. Exact edits
**File 1: `src/shared/Configuration/CustomerConfig.luau`**: append two entries inside `ORDER_POOL`, after the `Strawberry Syrup` entry and before `} :: { PoolEntry },`. Nothing else in the file changes (no PAY_TABLE edit, no new constant).
```lua
		{
			Key = "Espresso",
			Label = "Espresso",
			Weight = 8, -- PROPOSED (Jack): Espresso
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Espresso"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Coffees",
				Item = "Espresso",
				CustomInfo = { Iced = false, Sugar = false },
			},
		},
		{
			Key = "Mango Syrup",
			Label = "Mango Boba",
			Weight = 8, -- PROPOSED (Jack): Mango Boba
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Mango Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Mango", ["Tapioca Flavor"] = "Normal" },
			},
		},
```
- Weights 8/8 are the BIG-B1 D5 values (already PROPOSED there; <= `NEW_ENTRY_MAX_WEIGHT = 10`).
- Pick bands at L7 (total 128): Classic [0, 0.4297), Coffee [0.4297, 0.6641), Brownie [0.6641, 0.7813), Taro [0.7813, 0.8594), Strawberry [0.8594, 0.9375), Espresso [0.9375, 1).
- Pick bands at L8+ (total 136): Classic [0, 0.4044), Coffee [0.4044, 0.6250), Brownie [0.6250, 0.7353), Taro [0.7353, 0.8088), Strawberry [0.8088, 0.8824), Espresso [0.8824, 0.9412), Mango [0.9412, 1).
- Classic share is 78.1% at L7 and 73.5% at L8+ (>= 0.6). Average base pay per item at L8+ is 2.47, a change from the order mix only.

**File 2: `src/server/Tests/CustomerService.spec.luau`**: append only. No existing expectation changes: the L2 rolls 0.85 / 0.95 / 0.5 are unaffected because Espresso and Mango are not eligible at L2.
- Inside `describe("PickOrder (design 4.4)")`, after `should keep the classic picks at level 2`:
  - `should never pick Espresso or Mango Boba below their level`: for step = 0, 99, `local order = Rules.PickOrder(sequence({ step / 100, 0 }), nil, 6)`; expect `order.Item ~= "Espresso"` and `order.CustomInfo["Syrup Flavor"] ~= "Mango"` (each `.to.equal(true)`).
  - `should pick Espresso at level 7`: `Rules.PickOrder(sequence({ 0.95, 0 }), nil, 7)` -> `Category` `Coffees`, `Item` `Espresso`, `CustomInfo.Iced` false, `CustomInfo.Sugar` false, `CustomInfo.Size` `Small`.
  - `should keep Strawberry Boba below Espresso at level 7`: `sequence({ 0.9, 0 })`, level 7 -> `CustomInfo["Syrup Flavor"]` `Strawberry`.
  - `should pick Mango Boba at level 8`: `sequence({ 0.97, 0 })`, level 8 -> `Item` `Custom Boba`, Syrup Flavor `Mango`, Tapioca Flavor `Normal`.
  - `should pick Espresso at level 8`: `sequence({ 0.91, 0 })`, level 8 -> `Item` `Espresso`.
- Inside `describe("ORDER_POOL level ladder (B1)")`, after `should list the new drinks by level`, add `should list Espresso at 7 and Mango Boba at 8`: `Rules.NewDrinksAt(7)` has 1 entry, equal to `"Espresso"`; `Rules.NewDrinksAt(8)` has 1 entry, equal to `"Mango Boba"`; `#Rules.NewDrinksAt(6)` is 0.
- The existing generic loops already cover entries 6 and 7 with no edit: `should resolve pool entry {index}` at every size, `should keep pool entry {index} on the launch menu`, unique Key/Label/MinLevel, CLASSIC_MIN_SHARE at every level, and NEW_ENTRY_MAX_WEIGHT.

**Not touched:** `Rules.luau`, `ProgressionService.luau`, `Menu.luau`, `Progression.luau`, `CustomerService/init.luau`, `Npc.luau`, `src/server/Scripts/ActivityScript.server.luau`, and all place content.

**Ledger:** the packet author added the rows for both weights to `_meta/ECONOMY-LEDGER.md`. The builder does not edit it.

### E4. Exact strings
- Labels: `Espresso`, `Mango Boba`.
- `unlocksAt(7)` first entry: `New drink: Espresso`. `unlocksAt(8)` first entry: `New drink: Mango Boba`.
- ShiftCard next line (existing `nextUnlock`, no code change): at Level 6 `Next: Level 7 · New drink: Espresso`; at Level 7 `Next: Level 8 · New drink: Mango Boba`.
- Level-up toast: at HEAD, `_onLevelUp` builds only `Level up! You are now level {level}` (plus ` · New nametag: X`) and does not read `unlocksAt`. See E-O1. This extension does not change the toast.

### E5. Gate (from the repo root; save the output in the evidence dir)
- `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/CustomerConfig.luau src/server/Tests/CustomerService.spec.luau'` (Selene new findings = 0, `stylua --check` ok, rojo build).
- The same by hand: `selene src/shared/Configuration/CustomerConfig.luau src/server/Tests/CustomerService.spec.luau`; `stylua --check src/shared/Configuration/CustomerConfig.luau src/server/Tests/CustomerService.spec.luau`; `rojo build default.project.json -o <scratchpad>/b1ext.rbxl` (outside the repo).
- TestEZ in Studio: set `TESTS_ENABLED = true` in `src/server/Tests/RunTests.server.luau` locally, run the suite, and revert before finishing. Without Studio, record `UNVERIFIED: TestEZ` in summary.md.

### E6. Studio checks (Jack; the place-file instances these drinks depend on)
All of these are already on the live Regular Coffee and Taro chains. The checks confirm that nothing is missing.
- S-EXT-1 (Espresso place content): in Edit mode, Explorer shows a Model named `Cup` and a Model named `Coffee Machine` as descendants of `workspace.Assets.Kitchen`; Tools `ReplicatedStorage.SharedStorage.Tools.Kitchen.Cups["Small Cup"]`, `["Medium Cup"]` and `["Large Cup"]`; and in `ReplicatedStorage.SelectorModels`, a child `Cup` (Menu `Models["Cup"]`) and a descendant `Medium Cup` (the Coffee Machine dialog model).
- S-EXT-2 (Espresso chain): Play, clocked in: Large Cup -> Coffee Machine -> Espresso. Expected: held tool has `Item = "Espresso"` and `Size = "Large"`; no red error.
- S-EXT-3 (Mango place content): `workspace.Assets.Kitchen.Syrups` has at least one BasePart child; `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser` exists with parts `Liquid` and `Rim`. After Play starts, `workspace.Assets.Kitchen.Syrups["Mango Syrup"]` exists and its liquid is orange.
- S-EXT-4 (Mango chain): Medium Clear Cup -> Milk -> Mango Syrup -> Normal Tapioca. Expected: `Item = "Boba"`, `Syrup = "Mango"`, `Tapioca = "Normal"`, `Size = "Medium"`.
- S-EXT-5: Level 6 profile, serve 20 NPCs. Expected: no Espresso or Mango ticket; the shift card shows `Next: Level 7 · New drink: Espresso`.
- S-EXT-6: Level 8 profile, serve until an Espresso order and a Mango order appear (each about 1 in 17; Mango has an orange chip). Expected: each serves Perfect; Espresso pays like Regular Coffee and Mango like Classic boba.
- S-EXT-7: run the TestEZ CustomerService spec. Expected: all old and new cases pass.

### E7. Acceptance
- `ORDER_POOL` has 7 entries: 6 is Espresso, 7 is Mango Boba, and entries 1-5 are unchanged.
- `PickOrder` never returns Espresso below L7 or Mango below L8, and returns them at the rolls in E3.
- `Rules.NewDrinksAt(7) == { "Espresso" }`, `(8) == { "Mango Boba" }`, and `(2)` is unchanged.
- The gate passes with no new findings in the two files.

### E-Open items
- E-O1 (Prime; outside this extension): GAMEPLAY-PROGRESS-CALLOUTS step 2 (`_onLevelUp` text includes the first two `unlocksAt(level)` entries) is not in HEAD; `ProgressionService.luau` `_onLevelUp` builds only the level and the nametag. S-P2-2's expected toast `... · New drinks: Taro Boba, Strawberry Boba` will therefore not appear, and only the ShiftCard `Next:` line names drinks. Prime decides whether GAMEPLAY-PROGRESS-CALLOUTS needs a fix.
- E-O2 PENDING JACK (a pick probability; same status as the shipped Taro/Strawberry 10/10): pool weights Espresso 8 and Mango 8 (PROPOSED, BIG-B1 D5). No new price or reward.
