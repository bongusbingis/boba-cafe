# Retention Loop — the 7.8-Minute Cliff After Onboarding

Generated 2026-10-24 by the Primary Reasoning Agent (read-only; proposes, does not implement).
Evidence: `.deepcode/FTUE_TRACE.md` + code reads of `CustomerService`, `ShiftService`, `ProgressionService`, `OrderService`, `DailyRewardController`, Shop UI and `ProductIds`.

## 1. The post-onboarding journey, step by step

1. **Serve #3** → `OnboardingCompleted` fires (step 5). The 3rd serve also hits the first-shift target (`FIRST_SHIFT_SIZE = 3`), so `ShiftService:_endShift` runs:
   - `ShiftEnded` card (8 s, "First shift complete"), `Paycheck` receipt card,
   - funnel step 6 `FirstShiftCompleted`,
   - `CapsuleService` (ShiftEnding listener) grants **1 Regular Pet Capsule** (first shift only),
   - `ProgressionService` (ShiftEnding listener) pays shift XP → **Level 2** → `LeveledUp` card + toast naming unlocks (`Rules.NewDrinksAt(2)` = **Taro Syrup + Strawberry Syrup**),
   - the **nickname prompt** arms and opens after the shift card closes,
   - `_capsuleNudge` spawns — but only toasts if the player already has ≥75 BB (cheapest capsule). A first shift pays ~25 BB total, so **this nudge never fires for new players**.
2. The player is **still clocked in**; a new shift state silently starts with `SHIFT_SIZE = 10` (shift 2 is 10 serves — 3.3× the first).
3. The auto-grant chain has ended (`served >= 3`). From now on NPCs walk in via the pacing loop and the player must use the **full manual Take Order flow**: walk to the register → press Take Order → the tablet opens with the order text → manually punch the order into the Ordering page → submit (`Rules.ValidateSubmittedOrder`) → make → serve.
4. The Daily Rewards dialog already auto-opened after the *first* serve; after shift end there is no other shop/quest callout.

**The dead air:** between the end of the first-shift fanfare (~minute 4–5) and the player's next meaningful interaction, the game asks the player to (a) learn the hardest mechanic in the game with no tutorial (manual tablet order entry), (b) grind a 10-serve shift with only two new syrup flavors as the hook, and (c) find all of this themselves with no prompt. Players quit around minute 7.8 — right at that gap.

Supporting bug found while tracing: the server sends the tablet flag `Guided` (`CustomerService._onTakeOrderTriggered`), but the Ordering page only checks `npcOrderData.Prefill` for one-tap tutorial submit (`shared/UI/Pages/Ordering/init.luau:378`). `Prefill` is never set by the server today, so the guided tablet path is dead. The auto-grant hid this because it bypasses the tablet entirely.

## 2. Proposed loop changes (low-risk, code)

### Proposal 1 — Bridge order + teach "Take Order" once (attacks the dead air directly)
- After onboarding completes, grant **one bridge order** through the existing auto-grant path: in `_onServeTriggered`, where `servedNow < limit` gates the chain, add a one-shot grant when `servedNow == limit` (the 4th order) using a pool pick (`Rules.PickOrder`), assigned like a normal ticket — with a Notify: "Now take your next order at the register — walk up and press Take Order!"
- Make the first 2 post-tutorial counter orders **guided**: in `_onTakeOrderTriggered`, set `Guided = npc.RolledScriptedFor == player.UserId or served < FIRST_SESSION_COUNT + 2`; fix the client to honor `Guided` (or set `Prefill = true` for those) so the tablet one-tap flow teaches the mechanic before turning it off.
- **Files:** `CustomerService/init.luau` (small), `shared/UI/Pages/Ordering/init.luau` (one-line flag rename). **Goal:** no player ever meets an empty, unexplained tablet as their first post-tutorial action.

### Proposal 2 — "What's next" callout after the first shift (the visual hook)
- In `ShiftService:_endShift`, after the paycheck fires, send one Notify for first-shift players: "Shift 2 goal: serve 10 customers · You unlocked Taro & Strawberry syrups — try them now!" (and, see Revenue, an optional second line with an `OpenShop` action). The level-up card already names unlocks; this adds the **next goal** (the shift target) which nothing currently announces.
- **File:** `ShiftService.luau` (small, `pcall`-guarded, deferred). **Goal:** replace the silent 10-serve wall with an explicit goal.

### Proposal 3 — Auto-open Quests after the first shift
- `QuestService._ensureDailyQuests` already rolls 3 quests on day change. After the first `ShiftEnding`, notify "Daily quests available!" and auto-open the `QuestCard` once (client-side, mirroring `DailyRewardController`'s first-serve pattern, or server Notify with the quest count).
- **Files:** `QuestService.luau` or a `ShiftEnding` listener in `QuestCard`/`BottomRight` client code. **Goal:** give an instant, visible 10–15 min objective ("Serve 3 customers", "Order 2 bobas") right after the fanfare.

### Optional (PENDING JACK) — soften the second shift
- `SHIFT_SIZE = 10` is a wall right after a 3-serve tutorial. A ramp (`shift 2 = 5`, then +2 per shift to 10) needs a small `ShiftConfig`/`ShiftService` change and is a shift-economy tuning decision for Jack.

## 3. Revenue check (payer conversion 0.97%)

Findings:
- The money path is **live and wired**: `ProductIds.luau` has real SeasonPass (3721438870), StarterBundle (3721439110), BobaBucks packs (1780164398…), BobaBuddy products, and donations; `ProcessReceipt` maps them all into `ProductActionMap`.
- The Shop is a **top-bar tab** (`TopBar` "Shop" HudTabButton) with Featured/Products/Season pages, and dialogs can carry an `OpenShop` action (`AppDialogs` → `OpenShopRequested`). So discoverability, not capability, is the problem.
- The only post-shift spend prompt is `ShiftService:_capsuleNudge` — gated on balance ≥ cheapest capsule (**75 BB**). A first shift earns ~25 BB, so **new players are never nudged to the Shop at all**.
- The **free Ant Pet** (Group Benefit tab, group 3174578) is a perfect non-paywall Shop entry point and is currently only mentioned in a static toast list.

### Revenue proposal A — post-first-shift Shop nudge for everyone
- Replace/augment `_capsuleNudge`: after the first `ShiftEnding`, send a Notify with two lines: "You earned {pay} BB! Capsules start at 75 BB — check the Shop." **with an `OpenShop` action button** (mechanism already exists in `AppDialogs`). If balance < 75, the text becomes aspirational ("Keep serving — 75 BB buys your first pet capsule!"). Once per session.
- **Goal:** Shop visits per new player 0 → ≥1; primes the 75 BB capsule purchase (which also drives the pet-equip/tip loop).

### Revenue proposal B — free Ant Pet as the first Shop visit
- After onboarding completes (step 5) or after the first shift, Notify: "Free reward: join our group in the Shop to claim a free Ant Pet!" with `OpenShop` → Group Benefit tab. Converts Shop into a habit and the group join into retention; the Featured page then exposes StarterBundle/SeasonPass.
- **Files:** `CustomerService`/`ShiftService` (Notify) + optional `App` open-tab param (already supported). **Risk:** low; no price/promotion changes, no new UI tokens.

## 4. Metrics goals (post-change)

| Metric | Now | Target |
| --- | --- | --- |
| Avg playtime | 7.8 min | 15 min |
| Day-1 retention | 2.03% | 5%+ |
| Payer conversion | 0.97% | 2%+ (Shop-visit priming is the lever) |

## 5. Boundaries

- No prices, odds, rewards or product IDs change (Jack-approved data).
- Shift-target ramp and any new onboarding content are PENDING JACK.
- All proposed edits are presentation/nudge-layer changes; server authority and economy paths are untouched.
