# Telemetry Audit — Post-Update Coverage Gaps

Generated 2026-10-24 by the Primary Reasoning Agent. Read-only audit; exact insertion points provided for Gemini.
Files read: `src/server/Modules/AnalyticsEvents.luau`, `src/server/Modules/ShiftService.luau`, `src/server/Modules/CustomerService/init.luau`, `src/shared/UI/Utility/PassUpsell.luau`, `src/shared/UI/Components/Core/Hud/LevelUpCelebration.luau`, `src/shared/UI/Components/Core/Hud/PaycheckCard.luau`, `src/server/Scripts/ProcessReceipt.server.luau`.

## 0. What already exists (working)

- Funnel steps 1–8 (`Joined`, `ClockedIn`, `FirstStationUse`/`FirstItemTaken`, `FirstOrderServed`/`FirstServe`, `OnboardingCompleted`, `FirstShiftCompleted`, `FirstNicknameSet`, `FirstLevelUp`).
- Serve-level custom events: `NpcServed`, `ServeSeconds`, `PourAccuracy` (`CustomerService:_onServeTriggered` lines 1879–1881).
- Shift completion: `ShiftCompleted` with `state.Served` as the value (`ShiftService:_endShift` line 324); `ProgressionStart("Shift", n)` on clock-in.
- Purchases: `SeasonPassPurchased`, `BobaPartyPurchased`, `RushHourPurchased`, `NicknameChangePurchased` in `ProcessReceipt.server.luau`. **Missing:** Starter Bundle and BB-pack purchase events (see §6).

## 1. Shop Nudge — NOT tracked

**Current state:** `ShiftService:_postShiftShopNudge` (lines 435–470) shows the ButtonPrompt and calls `dialogService:OpenShop(player, "Currency")` on "View Shop" — no analytics anywhere.

**Add (both in `src/server/Modules/ShiftService.luau`, `_postShiftShopNudge`):**
- Impression — right after `self._shopNudged[player] = true` (line 452):
  `pcall(function() Knit.GetService("AnalyticsEvents"):Custom(player, "ShopNudgeShown", 1) end)`
- Click — inside the `if ok and choice == "View Shop" and player.Parent ~= nil then` branch (line 467), before or after `OpenShop`:
  `pcall(function() Knit.GetService("AnalyticsEvents"):Custom(player, "ShopNudgeClicked", 1) end)`

**Also flag:** the shipped implementation calls `_postShiftShopNudge(player)` from `_endShift` for **every** shift (line 372), not just the first shift as `.deepcode/REVENUE_NUDGE_SPEC.md` specified (session-once, not first-shift-only). Either gate it on `summary.First` or pass `summary.Shift` and use it as the event value (`ShopNudgeShown` value = shift number) so dashboards can segment.

## 2. Pass Upsell — NOT tracked (needs a client→server path)

**Current state:** `PassUpsell.Row` renders the offer; its button calls `props.OnClick` (wired by `LevelUpCelebration`/`PaycheckCard` to `PassUpsell.Prompt(passId)`), which calls `MarketplaceService:PromptGamePassPurchase`. `PromptGamePassPurchaseFinished` notifies local `purchaseListeners`. **No analytics on impressions, clicks, or gamepass purchases.** Gamepasses never touch `ProcessReceipt`, so server-side purchase tracking cannot see them.

**Step A — add a client-callable Custom to `src/server/Modules/AnalyticsEvents.luau`** (the service is server-only today; `Client = {}`):
```lua
function AnalyticsEvents.Client:Custom(player: Player, name: any, value: any)
    if typeof(name) ~= "string" then
        return
    end
    self.Server:Custom(player, name, if typeof(value) == "number" then value else 1)
end
```
Knit passes the calling `Player` as the first argument, matching `ShiftService.Client:SetClockedIn` etc. Server `Custom` already exists (line 162).

**Step B — events in `src/shared/UI/Utility/PassUpsell.luau`:**
- Click — top of `PassUpsell.Prompt(passId)` (line 140):
  `pcall(function() Knit.GetService("AnalyticsEvents").Client:Custom(Players.LocalPlayer, "PassUpsellClicked", passId) end)`
- Purchase — in the `PromptGamePassPurchaseFinished` handler inside `connectFinished` (lines 80–90), when `wasPurchased == true`:
  `pcall(function() Knit.GetService("AnalyticsEvents").Client:Custom(player, "PassPurchased", passId) end)`

**Step C — impression events (one ref-guarded fire per card mount):**
- `src/shared/UI/Components/Core/Hud/LevelUpCelebration.luau`: in the effect where `showUpsell` becomes true (around line 272), guard with a `React.useRef(false)` and fire
  `AnalyticsEvents.Client:Custom(Players.LocalPlayer, "PassUpsellShown", offerPassId)`.
- `src/shared/UI/Components/Core/Hud/PaycheckCard.luau`: same pattern where `showOffer` becomes true (around lines 176–178).

Result: `PassUpsellShown` (value = passId), `PassUpsellClicked` (value = passId), `PassPurchased` (value = passId). Level-2 vs later is segmentable by joining with `FirstLevelUp`/level attributes.

## 3. Ant Pet Prompt — NOT tracked

**Current state:** `CustomerService:_onServeTriggered` lines 1884–1907 show the "Free Reward!" ButtonPrompt and call `OpenShop(player, "GroupBenefit")` on "Go to Shop". No analytics.

**Add (in `src/server/Modules/CustomerService/init.luau`, the block at 1884–1907):**
- Impression — right after `self._groupNudged[player] = true` (line 1885):
  `pcall(function() Knit.GetService("AnalyticsEvents"):Custom(player, "AntPetPromptShown", 1) end)`
- Click — in the `if ok and choice == "Go to Shop" and player.Parent == Players then` branch (line 1902):
  `pcall(function() Knit.GetService("AnalyticsEvents"):Custom(player, "AntPetPromptClicked", 1) end)`

## 4. Funnel Drops — per-item tutorial serve events MISSING

**Current state:** only `NpcServed`/`ServeSeconds`/`PourAccuracy`. We cannot see whether players churn on tutorial order #1 (Brownie), #2 (Coffee) or #3 (Boba).

**Add inside the existing analytics `pcall` block in `_onServeTriggered` (lines 1869–1882), after `PourAccuracy`:**
```lua
-- Per-item serve (safe string from the first spec's ServeItem)
local servedItem = if npc.Specs[1] ~= nil and typeof(npc.Specs[1].Item) == "string" then npc.Specs[1].Item else "Unknown"
a:Custom(player, "ServedItem_" .. servedItem, 1)

-- Tutorial order index 1/2/3 — this is the churn signal for the new flow
if npc.Scripted == true then
    a:Custom(player, "TutorialOrderServed_" .. tostring(servedBefore + 1), 1)
end
```
`servedBefore` is already computed at line 1868. Resulting events: `ServedItem_Fudge Brownie`, `ServedItem_Regular`, `ServedItem_Boba`, and `TutorialOrderServed_1/_2/_3`. A drop between `TutorialOrderServed_1` and `TutorialOrderServed_3` is the order-#3 Boba churn.

## 5. Retention — "Shift 2 Started" MISSING

**Current state:** `ShiftCompleted` exists (with served count). No event marks the start of shift 2, so we can't measure the 10-serve second-shift loop.

**Add in `src/server/Modules/ShiftService.luau`, `_endShift`, inside the analytics `pcall` block (lines 316–325), next to `ShiftCompleted`:**
```lua
if state.Completed == 0 then
    a:Custom(player, "Shift2Started", 1)      -- first shift ended; shift 2 begins
elseif state.Completed == 1 then
    a:Custom(player, "Shift2Completed", state.Served)  -- shift 2 done with serve count
end
```
(`state.Completed` is the count of shifts completed BEFORE this one; 0 = first shift ending → shift 2 starts; 1 = second shift ending.)

## 6. Bonus gaps found while auditing

- **Starter Bundle has no purchase event.** `ProcessReceipt` maps the bundle but only SeasonPass/BobaParty/RushHour/NicknameChange fire `Custom` purchase events. Add `Knit.GetService("AnalyticsEvents"):Custom(player, "StarterBundlePurchased", 1)` in the bundle grant path (`StarterBundleReceipts.grant` returns true, or the ProcessReceipt block that merges `BuildActions()`).
- **BB packs have no purchase event.** Add `Custom(player, "BobaBucksPackPurchased", productId)` (or the pack tier as value) in the BobaBucks pack action block in `ProcessReceipt.server.luau`.

## 7. Event naming summary

| Event | Value | Where |
| --- | --- | --- |
| `ShopNudgeShown` / `ShopNudgeClicked` | 1 (or shift #) | `ShiftService:_postShiftShopNudge` |
| `PassUpsellShown` / `PassUpsellClicked` / `PassPurchased` | passId | `PassUpsell.luau` + the two HUD cards (client→server via new `AnalyticsEvents.Client:Custom`) |
| `AntPetPromptShown` / `AntPetPromptClicked` | 1 | `CustomerService:_onServeTriggered` |
| `ServedItem_<Item>` / `TutorialOrderServed_1..3` | 1 | `CustomerService:_onServeTriggered` analytics block |
| `Shift2Started` / `Shift2Completed` | 1 / served | `ShiftService:_endShift` |
| `StarterBundlePurchased`, `BobaBucksPackPurchased` | 1 / productId | `ProcessReceipt` / `StarterBundleReceipts` |

All server-side calls stay inside existing `pcall` guards; the only new surface is `AnalyticsEvents.Client:Custom` with a string type check.
