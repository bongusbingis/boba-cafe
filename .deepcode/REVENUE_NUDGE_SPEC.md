# Revenue Nudge Spec — Post-First-Shift Shop Prompt (Proposal A)

Generated 2026-10-24 by the Primary Reasoning Agent. Spec only — Gemini implements after review.
Source: `.deepcode/RETENTION_LOOP.md` Proposal A + code reads of `ShiftService`, `DialogService`, `AppDialogs`, `SmallNotification`, `App.luau`.

## Goal

After a player's **first shift** ends, show one actionable, non-intrusive prompt that can open the Shop on the Currency tab. This replaces the current dead nudge (`_capsuleNudge`), which only fires when the player already has ≥75 BB — a first shift pays ~25 BB, so new players are never nudged.

## Why a dialog, not a toast

- `DialogService:Notify` → `NotificationSignal` → `SmallNotification.Push`. **SmallNotification toasts have no buttons and no click handling** (`src/shared/UI/Components/Core/Hud/SmallNotification.luau` — icon + label, auto-dismiss ~3.5 s). They cannot carry an `OpenShop` action.
- The existing actionable path is `DialogService:CreateDialog(player, "ButtonPrompt", props)`, which returns a Promise of the chosen button text, followed by `DialogService:OpenShop(player, pageKey)`.

## Exact payload shapes (verified)

**Server → client dialog (`src/server/Modules/DialogService.luau`):**
- `CreateDialog(player, "ButtonPrompt", props)` fires `Client.DialogSignal(player, "CreateDialog", { id, type = "ButtonPrompt", props })` (line 65). `props.Buttons` entries are `{ Text = string, Color = Color3? }` — same shape as the existing clock-in upsell in `CustomerService:_ensureClockedIn` (`{ Text = "Clock In", Color = Styles.GREEN }`).
- `DialogService:OpenShop(player, pageKey?)` fires `Client.DialogSignal(player, "OpenShop", pageKey or "Currency")` (line 150-151). Its contract comment: only call it **after the player's own click on a dialog button** — never as an unprompted pop-up.

**Client handling (`src/client/Modules/AppDialogs.luau`):**
- `DialogService.DialogSignal:Connect(function(action, ...) ... elseif action == "OpenShop" then DialogController.OpenShopRequested:Fire(...) end)` (lines ~265-271).
- `src/shared/UI/App.luau` listens to `OpenShopRequested(tab, highlightKey)` and opens `Pages.Shop` on the requested tab (lines ~88-91, ~115-141). Default tab string from the server is `"Currency"`.

**ButtonPrompt component:** `src/shared/UI/Components/Dialogs/ButtonPrompt.luau` (resolve value = the pressed button's `Text`). Styles colors come from `shared/UI/Styles` (`Styles.GREEN`, `Styles.RED`) — follow the `_ensureClockedIn` pattern exactly.

## Where the change goes

**File: `src/server/Modules/ShiftService.luau`** — replace `_capsuleNudge` (or add a sibling `_postShiftShopNudge`) and its call site in `_endShift`.

## Spec changes

1. **New function `ShiftService:_postShiftShopNudge(player, summary)`** (spawned from `_endShift`, `pcall`-guarded, exactly like `_capsuleNudge` is today):
   - Session-once guard: add `self._shopNudged = {} :: { [Player]: boolean }` (cleared in `PlayerRemoving`). Return early if `_shopNudged[player]`.
   - Only for the **first shift**: return early unless `summary.First == true` (Proposal A targets the first-shift moment; later shifts keep the old affordability toast).
   - Reuse the existing nickname-prompt wait: `task.wait(NUDGE_DELAY_SECONDS)`, then poll `NicknamePending` up to `NUDGE_NICK_WAIT_SECONDS` (this code already exists in `_capsuleNudge` — factor it out or duplicate it). If the nickname prompt is still open, return (try next shift end).
   - Player-valid checks: `player.Parent ~= nil` and `self:IsClockedIn(player)` (same as `_capsuleNudge`).
   - Read the balance with the existing guarded pattern: `self._data:GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()`; `currency.BobaBucks` may be nil.
   - Build the copy:
     - With balance: `Title = "Shift complete!"`, `Text = "You earned Boba Bucks this shift (balance: {bucks} BB). Check the Shop — pet capsules start at 75 BB!"`
     - Without balance: same text minus the balance parenthetical.
   - `local ok, choice = self._dialog:CreateDialog(player, "ButtonPrompt", { Title = ..., Text = ..., Buttons = { { Text = "View Shop", Color = Styles.GREEN }, { Text = "Later", Color = Styles.RED } } }):await()`
   - Set `self._shopNudged[player] = true` **before** the await (so a concurrent shift end can't double-show).
   - If `ok and choice == "View Shop"` and the player is still in game → `self._dialog:OpenShop(player, "Currency")`.
2. **Wire it in `_endShift`:** in the existing spawned nudge block (currently `self:_capsuleNudge(player)`), call the new function instead, then keep the legacy affordability toast inside `_capsuleNudge` for **non-first shifts** (or call `_capsuleNudge` after the dialog resolves for first shifts too, unchanged).
3. **`PlayerRemoving`:** add `self._shopNudged[player] = nil` next to `self._capsuleNudged[player] = nil`.
4. **Add `Styles` require** if not already present: `local Styles = require(ReplicatedStorage.Shared.UI.Styles)` (ShiftService currently requires only ShiftConfig/InventoryItemDefinitions).

## Acceptance criteria

- After the first shift card + nickname prompt close, exactly one ButtonPrompt appears: "Shift complete! … Check the Shop — pet capsules start at 75 BB!" with View Shop / Later.
- "View Shop" opens the Shop on the Currency tab. "Later" dismisses. Never auto-opens the Shop without the click (contract in `DialogService:OpenShop`).
- No double-show (session-once), no nudge while the nickname prompt is open, no nudge for shifts 2+ (those keep the existing 75 BB affordability toast), and no error if profile data is unreadable.

## Out of scope / boundaries

- No new UI components or tokens (ButtonPrompt + Styles already exist — DEC-013 compliance).
- No product/price changes; the 75 BB capsule price is referenced in copy only and is Jack-approved data.
- Pending Jack: nothing. This is a presentation/nudge change; but confirm copy wording with Jack if the shop team wants different phrasing.

## Optional follow-up (Proposal B)

Same mechanism, different trigger: after `OnboardingCompleted` (`CustomerService:_onServeTriggered`), a one-time ButtonPrompt "Free reward: join our group in the Shop to claim a free Ant Pet!" with `OpenShop(player, "GroupBenefit")` — only if the Shop page has a `GroupBenefit` tab key. Defer until Proposal A ships and is measured.
