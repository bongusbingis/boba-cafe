---
id: REALORDER-HEARTS
title: Hearts toast to the barista; wire the rating prompt; heart icons (X6 inert)
priority: P1
role: Mason
worker_tier: sonnet
release_gate: after
depends_on: [REALORDER-SHIFT]
status: READY
source_commit: 098175c
read_scope: [src/server/Modules/RealOrderService.luau (_askHearts, _onOrderPickedUp), src/shared/UI/Components/Dialogs/ButtonPrompt.luau, src/server/Tests/RealOrder.spec.luau]
write_scope: [src/server/Modules/RealOrderService.luau (_askHearts, new helper HeartsToast, one call site in _onOrderPickedUp), src/server/Tests/RealOrder.spec.luau (append only)]
invariants:
  - "SENTRY REVIEW REQUIRED (money path: edits RealOrderService, the payout file)."
  - "Serve-path no-yield: the call site goes AFTER the payout and after REALORDER-SHIFT's block, inside task.defer + pcall; nothing is added between the pickup guards and CurrencyService:Modify."
  - "QuestService:AdvanceQuest can yield; the final inline AdvanceQuest stays last."
  - "No economy change: hearts are a stat (HeartsReceived/HeartsCount), not currency; no BB, Points or XP added. No profile field added, renamed or removed."
  - "DEC-013: no new UI; the toast uses DialogService:Notify exactly like the existing Real customer toast."
  - "DEC-008: no heart icon is built or substituted (HARD-STOP 1)."
acceptance:
  - "After a fresh real-order pickup the customer sees the Rate your barista prompt (buttons stay 1-5)."
  - "Tapping N gives the barista HeartsReceived +N, HeartsCount +1 and the toast '<Name> gave you N heart(s)!'."
  - "Dismiss or timeout: no stat change, no toast, no second prompt for that order."
  - "Throttled (4th+ pair serve) pickups show no prompt."
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/RealOrderService.luau src/server/Tests/RealOrder.spec.luau'"
  - "rojo build default.project.json -o <scratchpad>/boba.rbxlx"
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/REALORDER-HEARTS
forbidden: [WORKER-PRIMER section 8, "editing ButtonPrompt.luau or PromptButton.luau", "building or guessing a heart image, emoji or glyph for the buttons", "changing economy, ProfileTemplate or analytics reasons"]
---
Read [WORKER-PRIMER](_meta/WORKER-PRIMER.md) first; rules are not repeated here.

## Source excerpt
X5 (review HEAD c77e20c)
- What: Hearts to the barista: "Alex gave you 5 hearts!"
- Why: Social payoff for serving real people
- Files: RealOrderService._askHearts (async, after payout); after M4-FIX-REALORDER-QUEST commits
- Effort: XS
- Risk: Low
- Tag: OBVIOUS

X6 (review HEAD c77e20c)
- What: Heart icons on the rating buttons (instead of "1"-"5")
- Why: Already an open question for Jack
- Files: RealOrderService
- Effort: XS
- Risk: Low
- Tag: JACK (open)

## Verified at 098175c (important)
- `RealOrderService:_askHearts` is defined but has NO caller anywhere in `src/` (grep `_askHearts`: only the definition; same at f06a9bf and 49eec97). M2-HEARTS evidence says the prompt fires on pick-up, but `_onOrderPickedUp` never calls it, so no customer is asked and no barista gets hearts. X5 is meaningless without a caller, so this packet adds the call (D1).
- Heart icon search: `src/shared/UI/Styles.luau`, every file under `src/shared/UI/Components`, `src/shared/Configuration`, and the STYLE.md asset table (section 2.3). No heart image exists; the only "heart" hits are `Heartbeat` and pet code. Nothing confirmed, so X6 is HARD-STOP 1.

## Decisions made
- D1 Wire the prompt: in `_onOrderPickedUp`, after REALORDER-SHIFT's block and before the final inline `AdvanceQuest`, add the call below, only when `customer ~= nil` and `CountsForTeamChain(multiplier)` (fresh serve). Rationale: one prompt per fresh serve; throttled pairs cannot farm hearts or spam the customer.
- D2 The call is `task.defer` + `pcall`; `_askHearts` only builds a promise and does not yield.
- D3 The X5 toast goes to the barista inside the `andThen`, after both `IncrementStat` calls, in its own `pcall`, via `self._dialog:Notify(target, { Title = "Hearts", Description = text, Text = text })` (same table shape as the existing Real customer toast). Rationale: async, after payout, existing toast.
- D4 The customer name is captured before the async: `DisplayName` with `[<>&]` stripped, cut to `CUSTOMER_NAME_MAX` characters. Rationale: the customer may leave before the toast.
- D5 1 heart is singular; 2 to 5 plural.
- D6 X6 is INERT (HARD-STOP 1): buttons stay `HEART_BUTTONS` with Text "1" to "5"; `ParseHearts` and the button Text do not change. No placeholder glyph.
- D7 Prompt Title and Text stay exactly as shipped in `_askHearts`; do not edit them.

## Exact strings
- Toast Title: `Hearts`
- Toast text: `{name} gave you {n} hearts!` for n 2 to 5; `{name} gave you 1 heart!` for n 1. Example: `Alex gave you 5 hearts!`

## Exact numbers
`CUSTOMER_NAME_MAX = 20` (new local constant next to `HEARTS_TIMEOUT_SECONDS`). No economy numbers; ledger rows added: none.

## Signatures and insertion points
Pure helper after `ParseHearts`:
```lua
function RealOrderService.HeartsToast(name: string, hearts: number): string
	local noun = if hearts == 1 then "heart" else "hearts"
	return `{name} gave you {hearts} {noun}!`
end
```
In `_askHearts`, after the `if self._rating[customer]` guard add (gsub returns two values, so keep it in its own local):
```lua
local cleaned = string.gsub(customer.DisplayName, "[<>&]", "")
local customerName = string.sub(cleaned, 1, CUSTOMER_NAME_MAX)
```
In the `andThen`, after `self._stats:IncrementStat(target, "HeartsCount", 1)` add:
```lua
pcall(function()
	local text = RealOrderService.HeartsToast(customerName, hearts)
	self._dialog:Notify(target, { Title = "Hearts", Description = text, Text = text } :: any)
end)
```
Call site in `_onOrderPickedUp` (after the REALORDER-SHIFT block, before the final `AdvanceQuest` pcall):
```lua
	if customer ~= nil and RealOrderService.CountsForTeamChain(multiplier) then
		task.defer(function()
			pcall(function()
				self:_askHearts(customer, barista)
			end)
		end)
	end
```
Tests (append to `RealOrder.spec.luau`, written not run): `HeartsToast("Alex", 5) == "Alex gave you 5 hearts!"`, `HeartsToast("Alex", 1) == "Alex gave you 1 heart!"`, `HeartsToast("Sam", 2) == "Sam gave you 2 hearts!"`.

## Studio checks (batched by Prime)
- S1: Two players; customer orders, barista serves, customer picks up. Expect the Rate your barista prompt with buttons 1-5.
- S2: Tap 5. Expect the barista toast `<Customer> gave you 5 hearts!`, HeartsReceived +5, HeartsCount +1.
- S3: Tap 1. Expect `gave you 1 heart!`.
- S4: Dismiss, or wait 60 s. Expect no toast, no stat change, no second prompt for that order.
- S5: 4th order from the same pair within 10 min: no prompt.
- S6: Customer leaves before tapping: no error, no toast.

## Asset prerequisites
X6 only (not built): a confirmed heart image (rbxassetid, square) from Jack, plus a follow-up packet that adds an optional `Icon` to `ButtonDef` and `PromptButton` (write scope ButtonPrompt.luau, PromptButton.luau; STYLE.md pattern approval). Until then buttons show "1" to "5".

Open items:
- HARD-STOP 1: Which heart image asset id do you want on the rating buttons (or say "keep 1-5")?
- Observation (no action taken): real-order BB is paid by `self._currency:Modify(barista, "BobaBucks", pay)` with no reason argument, so analytics logs it as "Shop" (ShiftService passes "Gameplay"). Economy not changed.
- Observation: `_askHearts` was dead code before this packet; wiring it activates a prompt that has never shipped (dismissible, 60 s timeout, not a play block).
- Sentry review required before sign-off.

## Summary
- `_askHearts` has no caller at HEAD; the packet wires it after the payout (task.defer + pcall) for fresh serves only.
- X5: barista toast "Alex gave you 5 hearts!" (singular for 1) via DialogService:Notify after the stats, async.
- X6 HARD-STOP 1: no heart asset exists in shared/UI or STYLE.md; buttons stay 1-5, nothing substituted.
- Observation: real-order BB logs under "Shop" (no reason); not changed.
- Money path: Sentry review REQUIRED; no economy, profile or ledger changes.
