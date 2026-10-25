# UI Feedback Spec — 4 Live Bugs

Generated 2026-10-24 by the Primary Reasoning Agent. Spec only — Gemini implements after review.
Sources: Discord feedback + code reads (file:line refs from the `uhweifh` working tree).

---

## Issue 1 — Order Taking Overlap (NPC Take Order has no lock)

**Feedback:** "…when trying to take a customer's order, u can't select them when someone is already in the process of taking their order. it's annoying when you're in the middle of it and then it closes because someone else was doing it first."

**Root cause (two separate flows):**

1. **NPC Take Order (`CustomerService/init.luau:1465 _onTakeOrderTriggered`) has no lock.** Any number of baristas can press Take Order on the same NPC; each gets `OpenOrderingTablet` fired and each becomes `_activeOrderingNpc[player] = npc` and `_orderTakers[npc][player] = true`. When one barista submits, `_submitNpcOrder` (lines ~1677–1693) fires `CloseOrderingTablet` to **every other taker** — the reported "it closes because someone else was doing it first." This is the real repro.
2. **Counter customer locks (`_onCounterTakeOrder`, `CounterLock.luau`) already work** — the first barista takes the 90 s lock, and the client already hides the prompt for others: `OrderController.refreshCounterPrompt` (`client/Modules/OrderController.luau:157-166`) shows the prompt only when `TakerUserId` is nil/0/self. The remaining gap is that the server prompt stays `Enabled = true` for everyone (the client hide is presentation-only, by design) and the lock-release tablet close also exists (`_releaseCounterLock`).

**Spec changes:**

A. **NPC lock, mirroring CounterLock:**
- In `_onTakeOrderTriggered`, before rolling/opening the tablet, check whether another barista already holds this NPC:
  - iterate `self._orderTakers[npc]` (or `_activeOrderingNpc` reverse lookup); if any holder exists who is not `player`, fire `_dialog:Notify(player, { Title = "Order taken", Description = "Another barista is taking this order." })` and return without opening the tablet.
  - Add an NPC model attribute `TakerUserId` (set to `player.UserId` on open, cleared on submit/cancel/leave/NPC-left) so the client can hide the prompt (below).
- Add `CustomerService.Client:CancelNpcOrder(player, npcId)` remote: when the tablet is closed without submitting, clear `_activeOrderingNpc[player]` and `_orderTakers[npc][player]` (and `TakerUserId` when this player was the holder). Without this, a barista who closes the tablet would block the NPC for everyone until the NPC leaves or someone submits.
- In `_submitNpcOrder` and `_onCustomerLeft`, also clear `TakerUserId` on the NPC model.

B. **Client hide for NPC Take Order prompts:**
- `KitchenController.updateServePrompts` (`client/Modules/KitchenController.luau:717-747`) currently leaves `Take Order` prompts as the server set them. Extend it: if `PromptAction == "Take Order"`, show only when the model's `TakerUserId` is nil/0/`LocalPlayer.UserId` (and the player is clocked in, which is already gated elsewhere); hide otherwise.

C. **Counter lock hardening (small):** in `_onCounterTakeOrder`, keep `CounterLock.CanTake` as-is; optionally also set the prompt's `Enabled` server-side per client is not possible — keep the existing client hide but also refresh it when `TakerUserId` changes (already handled by `AttributeChanged`). No functional change needed; add a `TakerUserId`-driven `PromptAction` swap ("Taken") for clarity if desired.

**Acceptance:** Two baristas spamming Take Order on one NPC: exactly one tablet opens; the other gets the "Another barista is taking this order" toast; no open tablet is force-closed by the other's submit. Closing the tablet without submitting frees the NPC.

**Risk:** low — server-authoritative; the lock metadata is already present (`_orderTakers`). Must keep the submit fallback path (`_submitNpcOrder` accepts a taker from `_orderTakers`) intact.

---

## Issue 2 — Depositing/Serving to the Wrong NPC

**Feedback:** "when depositing order to the NPC perhaps only make it possible to give it to your NPC."

**Root cause:**
- The **NPC Serve prompt** allows anyone, not just the assignee: `CustomerService:_onServeTriggered` gates with `Rules.CanServe(assigned, fractionLeft)` (`CustomerService/init.luau:1736-1748`), which returns true for the assignee **or any barista once patience < `RESCUE_FRACTION` (0.3)**. `OrderSpec.PickTools` then matches whatever tools the rescuer holds, so a barista holding a drink for NPC A can hand it to NPC B (or a rescue can consume someone's drink). The client already shows "Rescue" to non-assignees (`updateServePrompts`), so this is by design — but players experience it as "I gave it to the wrong NPC."
- Real-player orders are **already** assignee-only: `OrderService:_getPlayerOrders(userId, "Being Prepared")` filters `preparedBy == userId` for deposit, and `_handleHandoff` re-checks `preparedBy == player.UserId`. No change needed there.

**Spec changes (NPC serve):**
1. **Client:** in `KitchenController.updateServePrompts`, remove the Rescue fallback: for `PromptAction == "Serve"`, show the prompt **only** when `AssignedUserId == LocalPlayer.UserId`; hide for everyone else. (Keep the patience-cue toasts C1/C3 untouched.)
2. **Server:** in `_onServeTriggered`, replace the `Rules.CanServe` check with `npc.AssignedUserId == player.UserId` (assignee only). Delete or bypass the rescue branch, `RESCUE_MULT` pay, "Customer rescued" notify, and `npc.Rescue` bookkeeping in the serve path — or, if rescue is to be kept as a deliberate mechanic, gate it behind an explicit new prompt ("Rescue — hold to confirm", `HoldDuration > 0`) and a separate `RescueIntent` flag rather than the same Serve path. **Decision needed from Jack:** remove rescue vs. opt-in rescue. Default spec: assignee-only (simplest, matches feedback).
3. Keep `Rules.CanServe` and `RESCUE_FRACTION` in `Rules.luau` if rescue remains opt-in; otherwise leave them unused (do not delete shared code the tests reference).
4. **Real-order deposit (no change):** confirm the existing per-barista visibility (`PickUpNodeVisibilityChanged` fired on `_assignOrder`/`_releaseClaimedOrder`) stays as-is; it already hides nodes for baristas with nothing to deposit and blocks occupied nodes ("This spot is taken.").

**Acceptance:** Only the assigned barista can trigger Serve on an NPC; the drink can never be consumed by another barista's serve. Rescue behavior per Jack's decision.

**Risk:** medium if rescue is removed (multiplayer fallback for abandoned NPCs disappears — `_handOff` already reassigns, so coverage remains); low if rescue becomes opt-in.

---

## Issue 3 — Ordering Tablet UI Flow

**Feedback:** "when clicking boba teas, if every drink is going to be custom, i don't think this screen is necessary. just bring us directly to the flavors screen. i also wish that when u press the back button… it just took u back one screen instead of to the beginning."

**Root cause (two findings):**

1. **Single-item categories still show the ItemSelect screen.** `onCategorySelected` (`Ordering/init.luau:507-510`) always does `setPage("ItemSelect")`. For "Boba Teas" the ItemSelect page shows exactly one card ("Custom Boba"). 
2. **Back on the size screen jumps to the root.** The TopBar back is wired to `goBack` (`init.luau:1195`), but the SizeOptions page's own Back button calls `props.OnCancel` (`SizeOptionsPage.luau:297`), and `init.luau:744` passes `OnCancel = cancelItemConfig` — which clears all state and returns to `CategorySelect` (the beginning). Also, if ItemSelect is auto-skipped (change #1), `goBack`'s `RequiredSelection idx==1 → ItemSelect` branch would resurrect a screen the player never saw.

**Spec changes (`src/shared/UI/Pages/Ordering/init.luau` + `SizeOptionsPage.luau`):**
1. **Bypass single-item categories:** in `onCategorySelected(categoryKey)`, after `setSelCategory`, count the items in `FoodTable[categoryKey].Items`. If exactly one, call `onItemSelected(thatKey)` directly (it already sets `selItemKey`, builds `customInfo`, the required-selection queue, and the correct next page). Set a state flag `itemSelectSkipped = true` (reset to false on category change / add / cancel).
2. **Back = pop one level:** 
   - Add a `history` stack (or reuse the existing page-state transitions) so `goBack` returns to the previous screen:
     - `SizeOptions` → `RequiredSelection` at last index (existing logic is correct) or `ItemSelect` when the queue is empty — **but if `itemSelectSkipped`, go to `CategorySelect`**.
     - `RequiredSelection idx == 1` → `ItemSelect` (or `CategorySelect` when `itemSelectSkipped`).
     - `ItemSelect` → `CategorySelect` (existing).
   - Fix the SizeOptions page: pass `OnBack = goBack` into `SizeOptionsPage` and change its internal Back button (`SizeOptionsPage.luau:297`) to call `props.OnBack` instead of `props.OnCancel`. Keep `OnCancel` only for an explicit "Cancel item" affordance if the design keeps one.
3. Title guard: when skipping ItemSelect, the `topBarTitle` for `RequiredSelection` already reads from the queue (line 455), so no change needed.

**Acceptance:** Tapping "Boba Teas" lands directly on the Syrup Flavor screen (skipping the one-card item screen). Back from Size → Tapioca → Syrup → (skipped ItemSelect) → CategorySelect; never resets to the category root mid-configuration.

**Risk:** low — client-only state machine; no server contract changes (the submitted `{ Category, Item, CustomInfo }` shape is unchanged).

---

## Issue 4 — Blender & Lid Confusion

**Feedback:** "make the step to step guide include blender & lid… i noticed that you could add a lid to drinks but it wasn't required to submit the order… also you have to restock the blender."

**Root cause:**

1. **The recipe card omits both.** `OrderSpec.buildStages` (`shared/Ordering/OrderSpec.luau:177-244`) builds only the required chain. Blender is excluded by `REQUIRE_BLENDER = false` (line 86) and Lids are never a stage. The `Step` type already reserves `Optional: boolean?` ("reserved for rows a player may skip; no step sets it yet", lines 43-44) — this is the designed extension point.
2. **Blender works but writes no attribute.** The Blender recipe (`Recipes.luau:331-359`) renames + re-colors but has no `SetToolAttributes` step, per the comment at lines 354-357. `OrderSpec` can't see it.
3. **Blender consumes stock.** `KitchenService:KnitStart` gives every station `Stock = KitchenConfig.GetDefaultStock(name)`; `GetDefaultStock("Blender")` returns `DEFAULT_STOCKS.Blender = 6`. Every successful interaction decrements `CurrentStock` (`KitchenService:KnitInit` onSuccess) and at 0 the station refuses with `OutOfStock` unless the UnlimitedStock perk is owned. An optional cosmetic step that also runs out and demands a restock box is exactly the annoyance reported. (`SetToolHoldingProperty` supports function values, so the blend itself succeeds — verified.)
4. Lids are purely cosmetic: `Recipes.Items.Lids` writes `Lid = true`; `OrderSpec.Match` ignores `Lid` by contract.

**Spec changes:**

A. **Card rows — optional steps (shared, no server authority change):**
- In `OrderSpec.luau`:
  - Insert an **optional Blender row** into the boba chain between Syrup and Tapioca: `{ Step = { Station = "Blender", Label = "Blender (optional)" }, Field = "Blended", Optional = true }` (only when the Blender is available — check `Recipes.Items.Blender ~= nil`, or keep the existing `REQUIRE_BLENDER` gate renamed to `SHOW_BLENDER_ROW`).
  - Append an **optional Lid row** after the final drink stage (boba, coffee, cocoa): `{ Step = { Station = "Lids", Label = "Lid (optional)" }, Field = "Lid", Optional = true }`.
  - Update `isDone` (line 270) and `StepState` (line 570) so an `Optional` stage never blocks `current`: treat an optional stage as done when its field is set OR when a later required stage is reached (for Blender: the tool's `Item` rank is beyond the Blender row, e.g. `Item == spec.Item`; for Lids: when the required chain is already complete). Rule: `current` is computed over **required** stages only; optional rows render checked/unchecked but don't advance the pointer.
  - `findProblem` stays unchanged (it already ignores `Blended`/`Lid`).
- In `Recipes.luau` Blender branch: append `{ "SetToolAttributes", { Blended = true } }` so the card can tick the optional row.
- `KitchenGuidance.Compute` (client) renders `Optional` rows as greyed "(optional)" labels; the highlight/beam still targets required steps only. Blender/Lids stay in `NEUTRAL_STATIONS` so using them never toasts "Next: …".

B. **Blender/Lids stop consuming stock (server, small):**
- Add a per-recipe flag `ConsumesStock = false` to the Blender and Lids recipes in `Recipes.luau` (or a `KitchenConfig.NO_STOCK_STATIONS = { Blender = true, Lids = true }`).
- In `KitchenService:KnitStart` (line 442), pass `Stock = nil` when the recipe opts out (so `PromptBuilder.Attach` never sets `CurrentStock`).
- `KitchenService`'s out-of-stock check (line 471) and onSuccess decrement (line 407) already no-op when `CurrentStock == nil` — verify and keep that invariant.
- Restock interaction on those stations becomes a no-op (`RestockStation` returns false when there is no stock), which is the desired behavior.

C. **Optional grading (no change):** `OrderSpec.Match` must continue to ignore `Lid`/`Blended` — a lidless/unblended drink still grades Perfect/Close. Do not add them to `MINOR_FIELDS`.

**Acceptance:** The card shows "Blender (optional)" and "Lid (optional)"; a player who skips both still completes the card and serves. The Blender never shows "Out of stock" or needs restocking; Lids likewise. Existing serves/grades are unchanged.

**Risk:** medium — `OrderSpec.Steps`/`StepState` feed the card, guidance, and the `KitchenGuidance` tests (`server/Tests/KitchenGuidance.spec.luau`, `KitchenAttributes.spec.luau`); those tests must be updated to the optional-row rules. Selene/StyLua/Rojo gates apply.

---

## Cross-cutting notes for Gemini
- All server changes keep authority on the server; client changes are presentation only.
- `Rules.CanServe`/`RESCUE_MULT` removal (Issue 2) is a design decision for Jack — implement the assignee-only default unless told otherwise.
- Run gates: Selene (no new findings), StyLua `--check`, `rojo build` to a path outside the repo, TestEZ with `TESTS_ENABLED = true` then reverted.
