> **Prime override (DEC-021):** Karen's description is at `ReplicatedStorage.SharedStorage.NPCStorage.Karen` (inserted by RIG-1). If it is missing, warn once and spawn a normal NPC. Don't block. Angry = Confused animation. ALSO: M2-PROGRESS added `CustomerConfig.ITEM_COUNT_BY_LEVEL` (multi-item NPC orders), but Npc/bubble handle only one item. Make the NPC order, bubble label and serve matching handle a list of items, using `OrderSpec.PickTools` for multiple specs. Keep it quick.

# M2-VARIANTS: VIP and Karen NPC variants
Model: sonnet   Studio: no   Depends on: M2-PROGRESS (`ProgressionService:GetLevel`, and edits the same CustomerService files)   Size: M

## Goal
From L6 some NPCs are gold-bubble VIPs (less patience, double pay); from L10 some are Karens (half patience, triple pay on a Perfect, stomp out after a Close). Settled by design §4.10, DEC-011 (Q10), DEC-015 (Q25).

## Read (only these)
- `M1.2/design.md` lines 281-286 (§4.10)
- `S3/evidence.md` lines 30-60 (v4 Karen: 10% of NPCs, `Special.Karen` description, dialogue pools)
- `src/server/Modules/CustomerService/Npc.luau`: `buildBubble`, `Npc.new`, `Leave`, `_setState`, and how the look (`HumanoidDescription`) is applied (grep `HumanoidDescription`)
- `src/server/Modules/CustomerService/init.luau`: `_spawnIfNeeded`, `_makeContext`, `_assign`, `_onServeTriggered`
- `src/server/Modules/CustomerService/Rules.luau` (`Payout`, `PatienceFor` or equivalent: grep `Patience`)
- `src/shared/Configuration/CustomerConfig.luau`, `CustomerDialogue.luau` (whole)
- `docs/STYLE.md` section 4.5 (lines 497-517)

## Write scope
- `src/shared/Configuration/CustomerConfig.luau`
- `src/server/Modules/CustomerService/Rules.luau`
- `src/server/Modules/CustomerService/Npc.luau`
- `src/server/Modules/CustomerService/init.luau`
- `src/server/Tests/CustomerService.spec.luau` (money cases only)

## Steps
1. **Config.** `VARIANTS = { VIP = { MinLevel = 6, Chance = 0.10, PatienceMult = 0.75, PayMult = 2 }, Karen = { MinLevel = 10, Chance = 0.10, PatienceMult = 0.5, PayMult = 3, PayMultGrade = "Perfect", StompOnClose = true } }`, each line `-- PROPOSED (Jack)` (design §4.10; Karen's 10% from v4, S3). Scripted first-session NPCs are always normal.
2. **Rules (pure).** `Rules.PickVariant(level, roll)`: Karen if `level >= 10` and `roll < Karen.Chance`; else VIP if `level >= 6` and the next band; else `nil`. Single `math.random()` roll, bands in that order. `Rules.PayoutVariant(basePay, variant, grade) -> number`: VIP pays `basePay * 2`; Karen `* 3` only for Perfect, otherwise unchanged; round, min `MIN_PAY`. Spec both (VIP Perfect 5 -> 10; Karen Perfect 5 -> 15; Karen Close 5 -> 5 before the Close halving: apply `PayoutVariant` to the already computed `Rules.Payout` result).
3. **Spawn.** In `init.luau` when an NPC is created, `variant = Rules.PickVariant(maxLevelOfClockedInBaristas, math.random())` (use `ProgressionService:GetLevel`; no baristas means no variant). Pass to `Npc.new`; set model attribute `Variant`.
4. **Patience.** At assignment, `PatienceTotal = base * PatienceMult` (keep one place that computes it).
5. **Look.** VIP: bubble background uses `Styles.GOLD` (existing token) instead of the normal colour; add a "VIP" text prefix to the bubble label. Karen: apply the `Karen` `HumanoidDescription`, found at `ReplicatedStorage.SharedStorage.NPCs` (search that folder by name `Karen`). If it is not there, STOP-AND-ASK (DEC-008: never substitute). Dialogue pools: use the `Karen` variants in `CustomerDialogue.luau` for greeting, wrong-order and leaving lines (DEC-015 bonus); VIP uses Default.
6. **Pay.** In `_onServeTriggered`, apply `Rules.PayoutVariant` to the result of `Rules.Payout`, before `CurrencyService:Modify`. The toast gets " · VIP" or " · Karen" appended.
7. **Karen stomps out.** After a Close serve of a Karen, call `npc:Leave("Served")` and play the Confused animation (DEC-015: Wave, Confused, Idle only; no new animations) on the way. If the Confused hook does not exist yet in `Npc.luau`, STOP-AND-ASK.
8. Robustness: variant code runs inside `pcall`; a failure falls back to a normal NPC.
9. `stylua` then `gate` on all changed files.

## Done when
- At L1-5 no variant appears; L6+ VIPs appear; L10+ Karens appear.
- Pay matches the two spec cases.
- Gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (Jack tests: set `Level` to 10 via the profile, wait for a Karen).

## STOP-AND-ASK
- `Karen` description missing from `ReplicatedStorage.SharedStorage.NPCs`: BLOCKED; ask Jack to import it (DEC-015).
- What does "angry emote" use? The only approved animations are Wave, Confused, Idle (DEC-015). This packet uses Confused; Jack to confirm.
- NPC seating after a serve: design §4 only says "seating with the drink is M2 (243 seats exist)"; no mechanism is written. NOT built here. Ask Jack for the rule (which seats, how long, then leave how).
- VIP spawn chance 10%: not in the design. Placeholder, confirm at the M3 gate.

## Evidence
`tasks/REVIVAL-001/M2-VARIANTS/evidence.md` (RUNBOOK step 5).
