---
id: BIG-B1-P1-AUDIT
title: B1 phase 1a - re-verify each new drink's recipe chain in source and hand Jack the Studio confirmation list
priority: P0
role: Lens
worker_tier: sonnet
release_gate: before
depends_on: []
status: READY
source_commit: 098175c
read_scope:
  - src/shared/Configuration/Progression.luau (MIN_LEVEL_BY_ITEM)
  - src/shared/Ordering/Menu.luau (SyrupFlavor, TapiocaFlavor, buildHotCocoaItems, COFFEE_NAMES, LAUNCH_ITEMS, LAUNCH_CHOICES)
  - src/shared/Ordering/OrderSpec.luau (FromMenuItem, buildStages)
  - src/shared/Kitchen/Recipes.luau (Recipes.Syrups, Recipes.Tapioca, Recipes.Items Mug / Milk / Coffee Machine / Hot Chocolate Powder, syrup and tapioca loops)
  - src/shared/Kitchen/RecipeConstructors.luau (makeCupGiver, makeHotChocolateVariant, makeCoffeeVariant)
  - src/server/Modules/KitchenService/init.luau (_spawnSyrupDispensers, _getMatchingModels)
  - src/server/Modules/CustomerService/Npc.luau (chipColor; read only)
write_scope: [.review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P1-AUDIT/evidence.md]
invariants:
  - read only: no edit under src/, docs/ or .claude/
  - DEC-008: "not found in source" is recorded as NEEDS-STUDIO-CHECK, never as "does not exist"
  - serve-path no-yield: not applicable (no code)
acceptance:
  - evidence.md holds the 6-row chain table below, each row re-checked by Grep at the current HEAD (symbol and quoted line)
  - every row is VERIFIED-IN-SOURCE or NEEDS-STUDIO-CHECK exactly as below, or the evidence explains the drift and sets RESULT BLOCKED
  - the Studio check list S1-S6 is copied into evidence.md unchanged for Prime's milestone run
checks: [none (no code); Grep commands and their output quoted in evidence.md]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P1-AUDIT
forbidden: [WORKER-PRIMER 8, any src edit, running Studio, changing a status from NEEDS-STUDIO-CHECK to VERIFIED without Jack's recorded answer]
---

Worker rules: `_meta/WORKER-PRIMER.md`. Design: `packets/BIG-B1.md` (sections 2-3). Source commit 098175c.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- B1 Rough plan (1): Architect: for each candidate item, confirm the giver, recipe and OrderSpec chain from source plus a Jack Play check.
- B1 Risks: a recipe that does not work end to end at the authored givers would strand players (revival plan 4.2 "Reconcile the content"); M0.4 saw boba recipes broken at one point. Each new syrup needs its dispenser and colour chip.
- P5: What: Menu grows with level (wire MIN_LEVEL_BY_ITEM). Files: CustomerConfig.ORDER_POOL, Menu.LAUNCH_ITEMS. Effort: M-L. Risk: Med. Tag: JACK (Q-G1).

## 2. Decisions made
- D1 The audit covers exactly the six pack entries: Taro Syrup, Strawberry Syrup, Hot Cocoa Classic, Strawberry Tapioca, Espresso, Mango Syrup. Rationale: BIG-B1 D1 fixed the list.
- D2 A chain is VERIFIED-IN-SOURCE when every station is either code-spawned (syrup dispensers) or one the live L1 Classic Milk Tea boba or Regular coffee chain already uses. Rationale: those place stations are exercised every shift; a new item adds no new place dependency.
- D3 A chain that needs any authored Model or Tool absent from the live L1 chains is NEEDS-STUDIO-CHECK and HARD-STOP 1. Rationale: DEC-008.
- D4 Drift rule: if HEAD no longer matches a cited symbol (renamed station, removed syrup, changed check string), the row becomes BLOCKED and the evidence names the file and symbol; P2 does not start.
- D5 Each row is checked with these Grep anchors (quote the hit line):
  - syrup: `Recipes.luau` `Recipes.Syrups` key line (e.g. `["Taro"] = Color3.fromRGB(224, 166, 255)`); `Menu.luau` `SyrupFlavor` key and the `LAUNCH_CHOICES["Syrup Flavor"]` list; `KitchenService/init.luau` `syrupDispenser.Name = name .. " Syrup"`.
  - tapioca: `Recipes.Tapioca` key; tapioca loop `name = name .. " Tapioca"`; `LAUNCH_CHOICES["Tapioca Flavor"]`.
  - cocoa: `buildHotCocoaItems` (`SIZE_MUG`), `HOT_COCOA_ITEMS` `{ "Classic", "Hot Chocolate" }`, `Recipes.Items` `["Mug"] = mugTool and`, Milk `"#Clear Cup|=Mug"`, `["Hot Chocolate Powder"] = makeHotChocolateVariant("", ...)`, `makeHotChocolateVariant` `Item = "Hot Chocolate"`.
  - coffee: `Recipes.Items["Coffee Machine"]` Buttons `{ Text = "Espresso" }` and branch `makeCoffeeVariant("Espresso", ...)`; Menu `COFFEE_NAMES` and `LAUNCH_ITEMS.Coffees`.
  - all: `OrderSpec.luau` `buildStages` boba branch (`syrup .. " Syrup"`, `tapioca .. " Tapioca"`), Mug branch (`spec.Item .. " Powder"`), coffee branch (`Station = "Coffee Machine"`).

## 3. Chain table (copy into evidence; re-verify each cell)
| Key (L) | Station / tool paths | Steps | Colour chip | Status |
|---|---|---|---|---|
| Taro Syrup (2) | Kitchen `Clear Cup`, `Milk`, `Normal Tapioca` (live); `workspace.Assets.Kitchen.Syrups["Taro Syrup"]` (spawned) | Clear Cup, Milk, Taro Syrup, Normal Tapioca | `Recipes.Syrups.Taro` 224,166,255 (Npc chipColor) | VERIFIED-IN-SOURCE |
| Strawberry Syrup (2) | as Taro, `Kitchen.Syrups["Strawberry Syrup"]` | Clear Cup, Milk, Strawberry Syrup, Normal Tapioca | 255,112,167 | VERIFIED-IN-SOURCE |
| Hot Cocoa Classic (3) | `workspace.Assets.Kitchen` Models `Mug`, `Milk`, `Hot Chocolate Powder`; Tool `ReplicatedStorage.SharedStorage.Tools.Kitchen.Mug` | Mug, Steamed Milk, Hot Chocolate Powder | coffee brown 204,161,135 (no syrup) | NEEDS-STUDIO-CHECK, HARD-STOP 1 |
| Strawberry Tapioca (4) | `workspace.Assets.Kitchen` Model `Strawberry Tapioca`; rest live | Clear Cup, Milk, Classic Milk Tea Syrup, Strawberry Tapioca | 255,250,214 (Classic Milk Tea) | NEEDS-STUDIO-CHECK, HARD-STOP 1 |
| Espresso (7) | Kitchen `Cup`, `Coffee Machine` (live); tools `Tools.Kitchen.Cups.<Size> Cup` (live) | `<Size>` Cup, Espresso | coffee brown | VERIFIED-IN-SOURCE |
| Mango Syrup (8) | as Taro, `Kitchen.Syrups["Mango Syrup"]` | Clear Cup, Milk, Mango Syrup, Normal Tapioca | 255,192,92 | VERIFIED-IN-SOURCE |

Recipe Book entry for each row: written by BIG-B1-P3 from `OrderSpec.Steps` (no hand text), so the Steps column is the book text.

Supporting prior evidence to cite (do not re-run): `M0.4/console-boot.txt` lines "Spawned syrups (19): ... Taro Syrup ... Mango Syrup ... Strawberry Syrup ..." and "Recipes.Items=50, with a matching model=49, missing model: Sink" (an older commit; supports, does not replace, S1-S2).

## 4. Exact strings
- Evidence status words, exactly: `VERIFIED-IN-SOURCE`, `NEEDS-STUDIO-CHECK`, `BLOCKED`.

## 5. Exact numbers
- None (no economy value in this phase).

## 6. Signatures and event names
- None.

## 7. UI spec
- None.

## 8. Studio checks (Prime batches; Jack runs; clocked in, Play Solo)
- S1 (HARD-STOP 1 cocoa): Edit mode Explorer: `workspace.Assets.Kitchen` has Models `Mug` and `Hot Chocolate Powder`, each with a PrimaryPart and a ProximityPrompt after Play starts; `ReplicatedStorage.SharedStorage.Tools.Kitchen.Mug` is a Tool with a part named `Liquid`. Play: Mug -> Milk -> Hot Chocolate Powder. Expected: held tool attributes Item = "Hot Chocolate", Size = "Mug"; no red error.
- S2 (HARD-STOP 1 pearls): Explorer: `workspace.Assets.Kitchen` has Model `Strawberry Tapioca` with a PrimaryPart. Play: Medium Clear Cup -> Milk -> Classic Milk Tea Syrup -> Strawberry Tapioca. Expected: Item = "Boba", Syrup = "Classic Milk Tea", Tapioca = "Strawberry", Size = "Medium".
- S3: Play: Small Clear Cup -> Milk -> Taro Syrup -> Normal Tapioca. Expected: Item = "Boba", Syrup = "Taro", Tapioca = "Normal"; dispenser liquid is lilac.
- S4: same with Strawberry Syrup. Expected: Syrup = "Strawberry"; dispenser liquid is pink.
- S5: same with Mango Syrup. Expected: Syrup = "Mango"; dispenser liquid is orange.
- S6: Large Cup -> Coffee Machine -> Espresso. Expected: Item = "Espresso", Size = "Large".

## 9. Asset prerequisites
- S1/S2 paths above. Nothing is built or moved by this phase.

Open items:
- HARD-STOP 1: S1 passes, Hot Chocolate may be enabled (yes/no).
- HARD-STOP 1: S2 passes, Strawberry Pearl Boba may be enabled (yes/no).

## Summary
- Read-only Lens pass: re-verifies the six B1 drink chains at the current HEAD with quoted Grep hits.
- Four chains are VERIFIED-IN-SOURCE (Taro, Strawberry, Mango syrups; Espresso): code-spawned or live-chain stations only.
- Hot Chocolate and Strawberry Pearl Boba need authored stations: NEEDS-STUDIO-CHECK, HARD-STOP 1.
- Produces Studio checks S1-S6 for Jack's milestone run; S1/S2 answers unlock the two gated entries.
- Drift at HEAD turns a row BLOCKED and stops P2.
- No code, no economy values.
