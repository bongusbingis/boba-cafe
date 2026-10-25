---
id: BIG-B1
title: Menu progression and drink mastery (design doc; phases P1-P4)
priority: P0
role: Mason
worker_tier: opus
release_gate: before
depends_on: [PATIENCE-RAMP, GAMEPLAY-PROGRESS-CALLOUTS, TICKET-RECIPE-LINK]
status: READY
source_commit: 098175c
read_scope:
  - src/shared/Configuration/Progression.luau (MIN_LEVEL_BY_ITEM, MAX_LEVEL)
  - src/shared/Configuration/CustomerConfig.luau (PoolEntry, ORDER_POOL, PAY_TABLE, PATIENCE_BONUS_SECONDS, ITEM_COUNT_BY_LEVEL)
  - src/server/Modules/CustomerService/Rules.luau (PickOrder, pickIndex, Payout)
  - src/server/Modules/CustomerService/init.luau (_pickOrderFor, _assign, _onServeTriggered CustomerResolved fire)
  - src/shared/Ordering/Menu.luau (FoodTable, SyrupFlavor, TapiocaFlavor, LAUNCH_ITEMS, LAUNCH_CHOICES, IsLaunchItem)
  - src/shared/Ordering/OrderSpec.luau (FromMenuItem, buildStages, Steps)
  - src/shared/Kitchen/Recipes.luau, src/shared/Kitchen/RecipeConstructors.luau
  - src/server/Modules/KitchenService/init.luau (_spawnSyrupDispensers, _getMatchingModels)
  - src/server/Modules/CustomerService/Npc.luau (chipColor)
  - src/server/Modules/ProgressionService.luau, src/shared/UI/Pages/Recipes/{init,Content}.luau
  - src/server/Tests/{CustomerService,KitchenAttributes,OrderSpec,BobaRecipe}.spec.luau
write_scope: [see each phase packet; this doc writes nothing]
invariants:
  - serve-path no-yield (WORKER-PRIMER 1): nothing yields between the serve guards and the payout; new code runs AFTER the payout, non-yielding or inside task.spawn; QuestService:AdvanceQuest can yield
  - DEC-008 / HARD-STOP 1: an item whose chain needs unverified place content ships disabled (Confirmed = false), never a substitute
  - DEC-013: Recipe Book locked state and stars use only Styles tokens and existing patterns
  - no new price: new items use existing PAY_TABLE categories
acceptance: [each phase packet's acceptance passes; pack ships with only VERIFIED-IN-SOURCE items enabled]
checks: [per phase: gate + rojo build (WORKER-PRIMER 2)]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B1
forbidden: [WORKER-PRIMER 8, editing Progression.MIN_LEVEL_BY_ITEM values, editing PAY_TABLE, editing place content, enabling a gated entry before Prime records Jack's confirmation]
---

Worker rules: `_meta/WORKER-PRIMER.md`. Source commit 098175c. Phases: `BIG-B1-P1-AUDIT` -> `BIG-B1-P2-POOL` -> `BIG-B1-P3-RECIPEBOOK` (all release gate before) -> `BIG-B1-P4-MASTERY` (after).

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- B1: Menu progression and drink mastery. Pitch: every few levels a new drink joins the order pool (Taro, Strawberry, Hot Cocoa, Mango, Espresso...). The Recipe Book shows locked drinks with "Unlocks at Level N". Later each drink earns bronze, silver and gold mastery stars from Perfect serves. Why: fixes F3. Variety is the main thing between minute 5 and session 10. It gives every level-up content and creates a visible ladder of goals. Data already in place: Progression.MIN_LEVEL_BY_ITEM (26 entries), Rules.PickOrder already filters MinLevel, CustomerConfig.ITEM_COUNT_BY_LEVEL, Menu.IsLaunchItem, the OrderSpec.Steps guidance, PAY_TABLE per category. Risks: a recipe that does not work end to end at the authored givers would strand players (revival plan 4.2 "Reconcile the content"); M0.4 saw boba recipes broken at one point. Pool weights could drown the classic drinks. Each new syrup needs its dispenser and colour chip. Dependencies: Jack's item list (Q-G1), a Keeper pass on weights, a per-recipe Studio run by Jack, a Recipe Book locked state (a new visual, Jack). Rough plan: (1) Architect: for each candidate item, confirm the giver, recipe and OrderSpec chain from source plus a Jack Play check. (2) Mason: ORDER_POOL entries with MinLevel from MIN_LEVEL_BY_ITEM; LAUNCH_ITEMS updated; specs for PickOrder by level. (3) The P1 callout names the new drink. (4) Phase 2: mastery stars (profile field Mastery[item], increment on Perfect after payout, Recipe Book display). Recommendation: phase 1 (4-6 items up to L8) before release. It is the single biggest retention lever. Mastery after release.
- P5: What: Menu grows with level (wire MIN_LEVEL_BY_ITEM). Why: Real payoff per level; variety beats boredom. Big bet B1. Files: CustomerConfig.ORDER_POOL, Menu.LAUNCH_ITEMS. Effort: M-L. Risk: Med. Tag: JACK (Q-G1).
- P7: What: Drink mastery stars: serving N Perfects of a drink gives it bronze, silver and gold stars in the Recipe Book. Why: Long-tail goals per recipe. Part of B1. Files: profile field, Recipe Book. Effort: M. Risk: Low. Tag: JACK.
- Jack (DEC-054 Q-G1): start with L2 Taro and Strawberry syrup, L3 Hot Cocoa Classic, L4 Strawberry tapioca, each only after a working end-to-end recipe.

## 2. Verified facts at 098175c
- `Progression.MIN_LEVEL_BY_ITEM` has 26 keys; nothing reads it (grep: only `Progression.luau`).
- `CustomerConfig.ORDER_POOL` has 3 entries, all `MinLevel = 1`: Classic Milk Tea boba 55, Regular coffee 30, Fudge Brownie 15. `PoolEntry = { Weight, MinLevel, Sized, OrderItem }`.
- `Rules.PickOrder(rng, config, level)` keeps entries with `MinLevel <= level`, falls back to the whole pool when none qualify, and adds `CustomInfo.Size` from `SIZE_WEIGHTS` (Small/Medium/Large) for `Sized` entries.
- `CustomerService:_pickOrderFor` and the extra-item loop in `_assign` pass `self:_levelOf(player)`; `_spawnIfNeeded` calls `Rules.PickOrder()` (level 1) for the placeholder order that `_assign` replaces through `npc:SetOrders`.
- `Menu.LAUNCH_ITEMS` already lists `Custom Boba`, Coffees `Espresso`, Hot Cocoas `Classic`; `LAUNCH_CHOICES` already lists syrups Taro, Strawberry, Mango and tapioca Strawberry. **No `Menu.luau` change is needed**; the existing "keep pool entry on the launch menu" test covers every new entry.
- Hot cocoa's Menu `Select.Size` is `{ "Mug" }` (`buildHotCocoaItems`). A `Sized = true` cocoa entry would get Small/Medium/Large and `OrderSpec.FromMenuItem` would reject it on "Size". The cocoa entry is therefore `Sized = false` with `CustomInfo.Size = "Mug"`.
- Syrup dispensers are code-spawned: `KitchenService:_spawnSyrupDispensers` clones `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser` once per `Recipes.Syrups` key into every BasePart of `workspace.Assets.Kitchen.Syrups`, named `<Syrup> Syrup`, `Liquid`/`Rim` coloured from `Recipes.Syrups`. A new syrup therefore needs no authored dispenser beyond the template and area the live Classic Milk Tea chain already uses. M0.4 console-boot listed Taro, Strawberry and Mango Syrup among the 19 spawned.
- The NPC colour chip is `Npc.luau` `chipColor`: `Recipes.Syrups[spec.Syrup]` for boba, GRAY for Grab, coffee brown (204,161,135) for every other drink (so Hot Chocolate shows coffee brown; cosmetic, Npc.luau is outside B1's lease).
- Every other station is matched by name: `KitchenService:_getMatchingModels` attaches a prompt to any descendant Model of `workspace.Assets.Kitchen` named exactly the `Recipes.Items` key. These Models are place content.
- `Content.build` dedups by `orderItem.Item`, so today every Custom Boba collapses into one block named "Custom Boba"; B1 changes it to one block per pool `Key` with a `Label`.
- `CustomerResolved` fires after the payout inside a pcall with `{ Kind, Grade, Pay, Fast, Combo, Items, Tip }`; it carries no order items. `ProfileTemplate` has no `Mastery` field; `playerProfile:Reconcile()` (DataService `loadPlayerProfile`) adds new template keys to old profiles.

## 3. Candidate chain audit (MIN_LEVEL_BY_ITEM, levels 2-8)
Station paths: a Model of that exact name anywhere under `workspace.Assets.Kitchen` (M0.4 saw givers under `.Givers`). "Live chain" = the same stations the L1 Classic Milk Tea boba or Regular coffee orders use every shift.

| Key (level) | Order item | Stations / tools (instance path) | Steps (OrderSpec.Steps) | Source file:symbol | Status |
|---|---|---|---|---|---|
| Taro Syrup (2) | Boba Teas / Custom Boba {Taro, Normal} | Kitchen `Clear Cup`, `Milk`, `Normal Tapioca` (live chain); `Kitchen.Syrups["Taro Syrup"]` spawned; tools `SharedStorage.Tools.Kitchen.Cups.<Size> Clear Cup` (live) | 1 `<Size> Clear Cup` 2 `Milk` 3 `Taro Syrup` 4 `Normal Tapioca` | Menu.luau:SyrupFlavor.Taro, LAUNCH_CHOICES; Recipes.luau:Recipes.Syrups.Taro + syrup loop; KitchenService:_spawnSyrupDispensers; OrderSpec:buildStages; Npc:chipColor (224,166,255) | VERIFIED-IN-SOURCE |
| Strawberry Syrup (2) | Custom Boba {Strawberry, Normal} | as Taro, dispenser `Kitchen.Syrups["Strawberry Syrup"]` | 1-4 as Taro with `Strawberry Syrup` | Recipes.Syrups.Strawberry (255,112,167); rest as Taro | VERIFIED-IN-SOURCE |
| Hot Cocoa Classic (3) | Hot Cocoas / Classic {Size Mug} -> Item `Hot Chocolate` | Kitchen `Mug`, `Milk`, `Hot Chocolate Powder`; tool `SharedStorage.Tools.Kitchen.Mug` | 1 `Mug` 2 `Steamed Milk` 3 `Hot Chocolate Powder` | Recipes.Items.Mug (`mugTool and ... or nil`), Milk `=Mug`, `makeHotChocolateVariant("")`; KitchenAttributes.spec "hot chocolate in a mug"; OrderSpec.spec "plain Hot Chocolate uses the Hot Chocolate Powder station" | NEEDS-STUDIO-CHECK (Mug, powder and Mug tool are on no live chain) -> HARD-STOP 1, gated |
| Macarons (4) | Grab | Food Display (live) + tools `Tools.Kitchen.Macaron.*` | 1 Food Display | Recipes.luau:foodDisplayTools | NEEDS-STUDIO-CHECK; not in pack (grab, not a drink) |
| Strawberry Tapioca (4) | Custom Boba {Classic Milk Tea, Strawberry} | Kitchen `Strawberry Tapioca` (authored); rest live chain | 1 `<Size> Clear Cup` 2 `Milk` 3 `Classic Milk Tea Syrup` 4 `Strawberry Tapioca` | Recipes.Tapioca.Strawberry + tapioca loop; Menu TapiocaFlavor.Strawberry, LAUNCH_CHOICES | NEEDS-STUDIO-CHECK (only `Normal Tapioca` is on a live chain) -> HARD-STOP 1, gated |
| Two-Item Orders (5) | n/a | n/a | n/a | already live: `ITEM_COUNT_BY_LEVEL[5] = 2`, `_assign` loop | VERIFIED-IN-SOURCE; no pool entry |
| Iced Coffee Option (6) | Coffees / Regular {Iced} | Kitchen `Ice Machine` (authored) | +`Ice` row | Recipes.Items["Ice Machine"] | NEEDS-STUDIO-CHECK; next pack |
| Espresso (7) | Coffees / Espresso {no ice, no sugar} | Kitchen `Cup`, `Coffee Machine` (live chain); tools `Cups.<Size> Cup` (live) | 1 `<Size> Cup` 2 `Espresso` (Coffee Machine choice) | Recipes.Items["Coffee Machine"] Buttons + branch `makeCoffeeVariant("Espresso")`; Menu COFFEE_NAMES, LAUNCH_ITEMS | VERIFIED-IN-SOURCE |
| Cappuccino (7) | Coffees / Cappuccino | as Espresso | as Espresso | same branch table | VERIFIED-IN-SOURCE; next pack (one new coffee per pack) |
| Sugar Option (7) | Coffees {Sugar} | Kitchen `Sugar` (authored) | +`Sugar` row | Recipes.Items.Sugar | NEEDS-STUDIO-CHECK; next pack |
| Mango Syrup (8) | Custom Boba {Mango, Normal} | as Taro, dispenser `Kitchen.Syrups["Mango Syrup"]` | 1-4 with `Mango Syrup` | Recipes.Syrups.Mango (255,192,92) | VERIFIED-IN-SOURCE |
| Matcha Syrup (8) | Custom Boba {Matcha, Normal} | as Taro | 1-4 with `Matcha Syrup` | Recipes.Syrups.Matcha | VERIFIED-IN-SOURCE; next pack |
| Mochis (8) | Grab | Food Display + `Tools.Kitchen.Mochi.*` | 1 Food Display | foodDisplayTools | NEEDS-STUDIO-CHECK; not in pack |

## 4. Decisions made
- D1 The pack adds 6 pool entries: Taro Boba (L2), Strawberry Boba (L2), Hot Chocolate (L3, gated), Strawberry Pearl Boba (L4, gated), Espresso (L7), Mango Boba (L8). Rationale: Jack's four plus the two verified drinks that fill the L5-L8 gap; 6 is the top of the 4-6 brief.
- D2 Four entries ship enabled (Taro, Strawberry, Espresso, Mango). Hot Chocolate and Strawberry Pearl Boba ship as pool data with `Confirmed = false` until Jack confirms HARD-STOP 1. Rationale: DEC-008; their stations are authored and sit on no live chain.
- D3 Levels come from `Progression.MIN_LEVEL_BY_ITEM[entry.Key]`; `CustomerConfig` requires `Progression` and sets `MinLevel` from it. The table values are not edited. Rationale: one source of truth, no duplicated numbers.
- D4 The L4 Strawberry Tapioca drink uses the Classic Milk Tea syrup. Rationale: the new thing to learn is the pearl station; Strawberry syrup plus Strawberry pearls would be one minor field away from the L2 Strawberry Boba and read as the same drink.
- D5 Pool weights are PROPOSED: 10, 10, 10, 8, 8, 8 (section 5). Classic entries keep 55/30/15. Rationale: each new drink shows up about 1 in 12 orders at its unlock level, enough to notice and learn, while the classics stay above 60% of the pool.
- D6 Classic-not-drowned rule: at every level 1..MAX_LEVEL the weight of the `MinLevel = 1` entries is at least `CLASSIC_MIN_SHARE = 0.6` of the eligible enabled weight, and also of the full pool with every gated entry enabled; no entry with `MinLevel > 1` weighs more than `NEW_ENTRY_MAX_WEIGHT = 10`. Both are tested.
- D7 Pay uses existing categories only: boba 3, coffee 2, hot cocoa 2 (`PAY_TABLE`, DEC-024). No new price key. Patience uses existing `PATIENCE_BONUS_SECONDS`.
- D8 `PickOrder` skips `Confirmed == false` entries everywhere, including the fallback. Fallback order: enabled entries regardless of level, then `{ ORDER_POOL[1] }`. Rationale: a gated item must never reach a customer by the fallback path.
- D9 Pool entries gain `Key` (the MIN_LEVEL_BY_ITEM key) and `Label` (player-facing name). The three existing entries get `Key`/`Label` too; their order stays first so existing tests that read `ORDER_POOL[1]` keep passing.
- D10 Level-up callout: `Rules.NewDrinksAt(level)` returns the Labels of enabled entries whose `MinLevel == level` (level > 1). ProgressionService's `unlocksAt` (from GAMEPLAY-PROGRESS-CALLOUTS) puts `New drink: A` or `New drinks: A, B` FIRST, so the toast and the ShiftCard "Next:" line name the drink.
- D11 Recipe Book: one block per enabled pool `Key`, header = `Label`. Unlocked blocks keep today's step lines. Locked blocks (MinLevel above the player's `Level` attribute) show the name and `Unlocks at Level N` with no steps, wrapped in RichText `transparency="0.35"` (the PromptButton disabled-text value, STYLE 3.3). Gated entries do not appear. Order: unlocked in pool order, then locked by MinLevel ascending.
- D12 Mastery (P4, after release): profile `Mastery = { [Key]: number }` counts Perfect NPC serves per pool Key; tiers Bronze 10, Silver 30, Gold 75 (PROPOSED); 1/2/3 `★` in GOLD on the Recipe Book header; a toast at each new tier. No BobaBucks or XP reward. Rationale: pure long-tail goal, no economy change.
- D13 Mastery counts NPC serves only (CustomerResolved). Real-player orders are free-form menu items with no pool Key. Rationale: one serve path, no RealOrderService write.
- D14 The mastery increment lives in a new `MasteryService` listening to `CustomerResolved`; the only `CustomerService/init.luau` change is one payload field `OrderItems = npc.Orders`. Rationale: the serve path gains no code; the signal already fires after the payout.

## 5. Exact pool (P2 writes this)
| Key | Label | Category / Item | CustomInfo | Sized | MinLevel | Weight | Confirmed | Base pay | Patience s |
|---|---|---|---|---|---|---|---|---|---|
| Classic Milk Tea Boba | Classic Milk Tea Boba | Boba Teas / Custom Boba | Classic Milk Tea, Normal | true | 1 | 55 | (nil) | 3 | 70 |
| Regular Coffee | Regular Coffee | Coffees / Regular | Iced false, Sugar false | true | 1 | 30 | (nil) | 2 | 60 |
| Fudge Brownie | Fudge Brownie | Pastries / Fudge Brownie | {} | false | 1 | 15 | (nil) | 1 | 55 |
| Taro Syrup | Taro Boba | Boba Teas / Custom Boba | Taro, Normal | true | 2 | 10 PROPOSED | (nil) | 3 | 70 |
| Strawberry Syrup | Strawberry Boba | Boba Teas / Custom Boba | Strawberry, Normal | true | 2 | 10 PROPOSED | (nil) | 3 | 70 |
| Hot Cocoa Classic | Hot Chocolate | Hot Cocoas / Classic | Size "Mug" | false | 3 | 10 PROPOSED | false | 2 | 70 |
| Strawberry Tapioca | Strawberry Pearl Boba | Boba Teas / Custom Boba | Classic Milk Tea, Strawberry | true | 4 | 8 PROPOSED | false | 3 | 70 |
| Espresso | Espresso | Coffees / Espresso | Iced false, Sugar false | true | 7 | 8 PROPOSED | (nil) | 2 | 60 |
| Mango Syrup | Mango Boba | Boba Teas / Custom Boba | Mango, Normal | true | 8 | 8 PROPOSED | (nil) | 3 | 70 |

Pick shares (enabled only): L1 total 100 (55/30/15). L2-L6 total 120: classic boba 45.8%, coffee 25.0%, brownie 12.5%, Taro 8.3%, Strawberry 8.3%; L1 share 83.3%. L7 total 128 (78.1%). L8+ total 136 (73.5%). With both gated entries enabled, L8+ total 154 (64.9%, still >= 0.6). Average base pay per item: 2.40 at L1, 2.50 at L8 enabled, 2.49 all enabled (+4%, drift from mix only; no price changed).

## 6. Callout copy (P2)
- L2 toast: `Level up! You are now level 2 · New drinks: Taro Boba, Strawberry Boba`
- L7 toast: `Level up! You are now level 7 · New drink: Espresso`
- L8 toast: `Level up! You are now level 8 · New drink: Mango Boba`
- ShiftCard at L1: `Next: Level 2 · New drinks: Taro Boba, Strawberry Boba` (from GAMEPLAY-PROGRESS-CALLOUTS `nextUnlock`, unchanged code).
- After Jack confirms: L3 `New drink: Hot Chocolate`, L4 `New drink: Strawberry Pearl Boba` appear with no code change.

## 7. Recipe Book UI spec (P3, P4)
- Surface: the existing Staff Guide card in `Pages/Recipes/init.luau` (ROSE_MID fill, OFFWHITE 3.5 stroke, CORNER_CARD, aspect 0.75) and its single RichText `TextLabel` (FONT_FREDOKA, OFFWHITE, `px(35)`, wrapped, scrolling Y, ROSE_DEEP scrollbar). No geometry, colour, font or Instance is added.
- Unlocked block: `<b>{Label}</b>` then `<font face="DenkOne">{i}. {row.Label}</font>` per step (today's format); Grab items keep `Grab it from the display.`
- Locked block: `<font transparency="0.35"><b>{Label}</b>` newline `<font face="DenkOne">Unlocks at Level {MinLevel}</font></font>`.
- Mastery (P4) on unlocked blocks only: header `<b>{Label}</b> ` + earned stars `<font color="#{Styles.GOLD:ToHex()}">★…</font>` + unearned stars `<font transparency="0.35">★…</font>` (3 glyphs total; ★ already used by ShiftCard), then one DenkOne line with the progress text (P4 section 3).
- States: level from `Players.LocalPlayer:GetAttribute("Level")` (nil -> 1), live via `GetAttributeChangedSignal("Level")`; mastery read from `DataController.LocalPlayerData.Mastery` at render (nil -> {}).
- Phone 844x390: usePx floors at 0.75, so body text is ~26 px; a locked block is 2 short lines and wraps inside the existing label. No layout change; Studio check S-RB4 confirms legibility.

## 8. Phases and leases
| Phase | Gate | Writes | depends_on |
|---|---|---|---|
| BIG-B1-P1-AUDIT | before | evidence only | none |
| BIG-B1-P2-POOL | before | CustomerConfig.luau, Rules.luau, ProgressionService.luau (unlocksAt), Tests/CustomerService.spec.luau | P1-AUDIT, PATIENCE-RAMP, GAMEPLAY-PROGRESS-CALLOUTS |
| BIG-B1-P3-RECIPEBOOK | before | Pages/Recipes/Content.luau, Pages/Recipes/init.luau, NEW Tests/RecipeBookContent.spec.luau | P2-POOL, TICKET-RECIPE-LINK |
| BIG-B1-P4-MASTERY | after | NEW MasteryConfig.luau, NEW MasteryService.luau, NEW Tests/Mastery.spec.luau, ProfileTemplate.luau (add), CustomerService/init.luau (payload field), Pages/Recipes/{Content,init}.luau | P3-RECIPEBOOK, BIG-B5, ENGAGE-FRIEND-INVITE |

Lease notes for Prime: INVENTORY has BIG-B1 before BIG-B4 on Rules/CustomerConfig and before BIG-B6 on ProgressionService; read "BIG-B1" there as BIG-B1-P2-POOL. P4 writes `ProfileTemplate.luau` and `CustomerService/init.luau`, which INVENTORY does not list for B1: append BIG-B1-P4-MASTERY to the end of both chains (after ENGAGE-FRIEND-INVITE and BIG-B5).

## 9. Studio checks (Jack, one milestone run)
- S-B1-1 (HARD-STOP 1 cocoa): Explorer, Edit mode: `workspace.Assets.Kitchen` contains Models named `Mug` and `Hot Chocolate Powder`, each with a PrimaryPart; `ReplicatedStorage.SharedStorage.Tools.Kitchen.Mug` is a Tool. Play, clocked in: Mug -> Milk -> Hot Chocolate Powder gives a tool with attributes Item = "Hot Chocolate", Size = "Mug".
- S-B1-2 (HARD-STOP 1 pearls): `workspace.Assets.Kitchen` contains a Model `Strawberry Tapioca` with a PrimaryPart. Play: Clear Cup -> Milk -> Classic Milk Tea Syrup -> Strawberry Tapioca gives Item = "Boba", Syrup = "Classic Milk Tea", Tapioca = "Strawberry".
- S-B1-3..9: see P1-AUDIT (verified drinks end to end), P2-POOL and P3-RECIPEBOOK lists.

## 10. Asset prerequisites
- Enabled items: none beyond what the live L1 chains already use (`Kitchen.Syrups` area, `SelectorModels.Kitchen.SyrupDispenser`, `Clear Cup`, `Cup`, `Milk`, `Normal Tapioca`, `Coffee Machine`, `Cups.*` tools).
- Gated items: the S-B1-1 and S-B1-2 paths. Missing content never errors: `Recipes.Items.Mug` is nil without the tool, KitchenService warns once for a missing kitchen, and a gated entry is never picked.

Open items:
- HARD-STOP 1: Do `workspace.Assets.Kitchen.Mug`, `workspace.Assets.Kitchen["Hot Chocolate Powder"]` and the Tool `ReplicatedStorage.SharedStorage.Tools.Kitchen.Mug` exist and make a Hot Chocolate end to end (yes/no). Yes -> the P2 follow-up deletes that entry's `Confirmed = false` line.
- HARD-STOP 1: Does `workspace.Assets.Kitchen["Strawberry Tapioca"]` exist and finish a Classic Milk Tea boba with Strawberry pearls (yes/no). Yes -> same follow-up for Strawberry Tapioca.
- LEASE: Prime appends BIG-B1-P4-MASTERY to the ProfileTemplate.luau and CustomerService/init.luau chains (section 8).
- NOTE (no action in B1): Hot Chocolate's NPC chip is coffee brown (`Npc.luau` `chipColor`); a later Npc packet can map cocoa to the powder colour.

## Summary
- Wires Progression.MIN_LEVEL_BY_ITEM into ORDER_POOL: 6 new entries, 4 enabled now (Taro L2, Strawberry L2, Espresso L7, Mango L8).
- Hot Chocolate (L3) and Strawberry Pearl Boba (L4) ship gated (`Confirmed = false`) behind HARD-STOP 1 Studio confirmation.
- Weights 10/10/10/8/8/8 PROPOSED; classics keep >= 60% of the pool at every level (tested); existing pay categories only.
- Level-up toast and ShiftCard "Next:" name the new drinks via `Rules.NewDrinksAt`.
- Recipe Book: one block per drink, locked ones show "Unlocks at Level N" at 0.35 transparency; existing tokens only.
- After release: Mastery stars (10/30/75 Perfect serves) via a new MasteryService off the serve path.
- Menu.luau needs no change (launch lists already cover every new entry).
