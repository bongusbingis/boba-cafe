---
id: REALORDER-SHIFT
title: Real-player serves count toward the barista's shift N
priority: P1
role: Mason
worker_tier: sonnet
release_gate: after
depends_on: []
status: READY
source_commit: 098175c
read_scope: [src/server/Modules/RealOrderService.luau (_onOrderPickedUp), src/server/Modules/ShiftService.luau (RecordCustomer, AddTip, CustomerResult), src/server/Tests/RealOrder.spec.luau, src/shared/Configuration/ShiftConfig.luau]
write_scope: [src/server/Modules/RealOrderService.luau (_onOrderPickedUp + new pure helper ShiftResult), src/server/Tests/RealOrder.spec.luau (append only)]
invariants:
  - "SENTRY REVIEW REQUIRED (money path: edits the RealOrderService payout function)."
  - "Serve-path no-yield: nothing yields between the pickup guards and CurrencyService:Modify (payout). The new code runs AFTER the payout and AFTER the AddXp pcall, inside task.defer wrapped in pcall. Add nothing before the payout line."
  - "QuestService:AdvanceQuest can yield; the existing inline barista AdvanceQuest stays the LAST statement, so the new block sits before it."
  - "No economy change: no BB, XP, price or reward value is added or altered. The shift star bonus (SHIFT_BONUS_PER_STAR = 5) is existing behavior."
  - "DEC-053 final decisions; DEC-054 Q-G10."
acceptance:
  - "A fresh real-order serve (PayMultiplier > 1) by a clocked-in barista raises their ShiftCount attribute by 1."
  - "A throttled serve (4th+ same pair in 10 min, multiplier 1) does not change ShiftCount."
  - "Shift summary Pay/Tips shows real-order pay exactly once (tip boost not doubled)."
  - "Payout amount and the Real customer toast are unchanged."
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/RealOrderService.luau src/server/Tests/RealOrder.spec.luau'"
  - "rojo build default.project.json -o <scratchpad>/boba.rbxlx"
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/REALORDER-SHIFT
forbidden: [WORKER-PRIMER section 8, "editing ShiftService.luau or CustomerService", "changing Rules.Payout, PayMultiplier, Record or any BB amount", "recording a Walkout"]
---
Read [WORKER-PRIMER](_meta/WORKER-PRIMER.md) first; rules are not repeated here.

## Source excerpt (H5, review HEAD c77e20c)
- What: Real-player serves count toward the shift N
- Why: A shift with real customers should feel like progress too
- Files: RealOrderService after payout → ShiftService:RecordCustomer
- Effort: XS
- Risk: Med
- Tag: JACK (Q-G10, approved in DEC-054)

## Decisions made
- D1 Who counts: the BARISTA. Shift state (`ShiftService._states`) exists only for clocked-in baristas; the customer is clocked out and `RecordCustomer` would no-op for them. Rationale: the shift card belongs to the server.
- D2 What is recorded: `Kind = "Served"`, `Grade = "Perfect"` when the pickup grade is `"Perfect"` else `"Close"`, `Pay` = payout minus the tip-boost extra, `Fast = false`, `Combo = 0`, `Tip = nil`. Rationale: real orders have no patience timer or NPC combo chain, so Fast and Combo stay neutral (`BestCombo = math.max(..., 0)` is harmless).
- D3 Walkouts are never recorded for real orders. Rationale: a real customer who does not pick up is not a walkout and must not lower stars.
- D4 Anti-double-count, part 1: real orders arrive from `OrderService.OrderPickedUp`, a path separate from `CustomerService:_onServeTriggered` / `CustomerResolved`, so one serve can never record twice. Rationale: verified in source; no extra guard needed.
- D5 Anti-double-count, part 2 (tip): `ShiftService:AddTip` already adds the boost extra to `state.Pay` and `state.Tips` inside the payout block, and `RecordCustomer` adds `result.Pay` to `state.Pay`. So record `Pay = pay - tipExtra` and `Tip = nil`; the extra is then counted once.
- D6 Anti-farm: record only when `RealOrderService.CountsForTeamChain(multiplier)` is true (fresh serves: the first 3 per barista/customer pair per 10 min). Rationale: friends cannot farm shift stars and the 5 BB/star bonus by repeating one order; same rule as the Team Combo chain.
- D7 Non-yielding via `task.defer` + `pcall`, placed after the AddXp pcall and before the final inline `AdvanceQuest` pcall. Rationale: `RecordCustomer` may call `_endShift` (Modify, quests); deferring protects the payout path.
- D8 `RecordCustomer` returns silently when the barista has no shift state (clocked out or left); no extra guard.
- D9 Self-serve and `#specs == 0` already return earlier in `_onOrderPickedUp`; nothing is recorded there.
- D10 Named Team Combo for real orders (SERVE-FEEDBACK D5): the existing `customerService:RecordTeamServe(grade or "Close")` call becomes `customerService:RecordTeamServe(grade or "Close", barista)`. Same pcall, same position after the payout; no other line changes.

## Exact strings
None (no new player-facing text; the shift pill already reads the `ShiftCount` attribute).

## Exact numbers
No new constants. Existing: `SHIFT_SIZE 10`, `FIRST_SHIFT_SIZE 5` (ShiftConfig). Ledger rows added: none.

## Signatures and insertion points
New pure helper, placed after `RealOrderService.CountsForTeamChain`:
```lua
-- CustomerResult for ShiftService:RecordCustomer from a real-order serve (REALORDER-SHIFT D2, D5).
function RealOrderService.ShiftResult(grade: any, pay: number, tipExtra: number): { [string]: any }
	return {
		Kind = "Served",
		Grade = if grade == "Perfect" then "Perfect" else "Close",
		Pay = math.max(0, pay - tipExtra),
		Fast = false,
		Combo = 0,
		Tip = nil,
	}
end
```
In `_onOrderPickedUp`:
1. Immediately before `if tipBonus > 0 and barista.Parent ~= nil then` add `local tipExtra = 0`. Inside the `if okExtra and typeof(extra) == "number" and extra > 0 then` block, right after `pay += extra`, add `tipExtra = extra`.
2. Directly after the `pcall(function() self._progression:AddXp(...) end)` statement and BEFORE the final `pcall(function() Knit.GetService("QuestService"):AdvanceQuest(barista, "RegularOrders", 1) end)`, insert:
```lua
	-- REALORDER-SHIFT: counts toward the barista's shift N (Q-G10), after the payout, non-yielding.
	if RealOrderService.CountsForTeamChain(multiplier) then
		local result = RealOrderService.ShiftResult(grade, pay, tipExtra)
		task.defer(function()
			pcall(function()
				Knit.GetService("ShiftService"):RecordCustomer(barista, result)
			end)
		end)
	end
```
Touch no line at or before `self._currency:Modify(barista, "BobaBucks", pay)`.

Tests (append to `RealOrder.spec.luau`, written not run): `ShiftResult("Perfect", 20, 0)` gives Grade Perfect, Pay 20; `ShiftResult("Close", 20, 5)` gives Pay 15 and Tip nil; `ShiftResult(nil, 10, 0).Grade == "Close"`; `ShiftResult("Perfect", 3, 5).Pay == 0`; Kind "Served", Fast false, Combo 0.

## Studio checks (batched by Prime)
- S1: Clock in as barista; a second player orders a real drink; barista serves; customer picks up. Expect shift count +1 and the Real customer toast unchanged.
- S2: Repeat with the same pair up to the 4th order within 10 min. Expect orders 1-3 each +1; order 4 pays 1x and the shift count does not move.
- S3: Finish a shift mixing NPC and real serves. Expect summary Served equals total serves and Pay matches BB earned.
- S4: Barista with a tip pass or pet: summary Tips equals the sum of boosts once.
- S5: Barista clocked out serves a real order: no errors in output.

## Asset prerequisites
None.

Open items: none. (Sentry review required before sign-off; the final inline `AdvanceQuest(barista, ...)` remains the last statement and can yield harmlessly there.)

## Summary
- The barista's shift counts a real serve: Served, Perfect/Close, Pay minus tip extra, Fast false, Combo 0, never a Walkout.
- Only fresh serves count (same rule as the Team Combo chain), so repeat-pair farming gives no stars.
- Tip extra is counted once (AddTip already adds it).
- New code runs after the payout in task.defer + pcall; one new pure helper ShiftResult plus spec.
- Money path: Sentry review REQUIRED. No economy values changed.
