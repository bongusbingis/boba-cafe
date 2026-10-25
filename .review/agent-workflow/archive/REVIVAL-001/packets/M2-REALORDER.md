# M2-REALORDER: real-player orders get auto-dispatched, a bubble and a regular stat
Model: sonnet   Studio: no   Depends on: M2-PROGRESS (`ProgressionService:AddXp`); M1.4e (done)   Size: M

## Goal
A clocked-out player orders at a register, a free barista is given the order automatically (no claiming), the customer wears a bubble so baristas can find them, keeps the drink, and the barista earns double pay for their first 3 orders from the same customer within 10 minutes. Settled by DEC-011 (Q17), design §4.9.

## Read (only these)
- `M1.2/design.md` lines 271-280 (§4.9)
- `src/server/Modules/OrderService.luau`: `_addOrder`, `_tryDispatchFromQueue`, `_claimNextOrder`, `_handlePickUp` (grep each), `CreateOrder` (lines 867-935), `GetPendingCount`, `HasActiveOrder`
- `src/server/Modules/CustomerService/Rules.luau` (`Payout` signature only) and `CustomerConfig.luau` (`PAY_TABLE`)
- `src/server/Modules/CustomerService/Npc.luau` lines 215-300 (`buildBubble`, to copy; do not edit)
- `src/server/Modules/StatisticsService.luau`; `src/shared/Configuration/ProfileTemplate.luau` lines 94-106
- `docs/STYLE.md` section 4.5 (lines 497-517)

## Write scope
- `src/shared/Configuration/RealOrderConfig.luau` (new)
- `src/server/Modules/RealOrderService.luau` (new)
- `src/server/Modules/OrderService.luau` (two server signals and the dispatch tweak only)
- `src/shared/Configuration/ProfileTemplate.luau` (add `RegularOrders = 0` to Statistics; if M2-SHIFT or M2-PROGRESS touched this file, rebase on their result)
- `src/server/Tests/RealOrder.spec.luau` (new; anti-farm rule only)

## Steps
1. **RealOrderConfig.luau**, each line `-- PROPOSED (Jack)` (Q17): `PAY_MULT = 2`, `BONUS_ORDER_COUNT = 3`, `WINDOW_SECONDS = 600`.
2. **OrderService signals.** Add server `OrderCreated = GoodSignal.new()` fired at the end of `_addOrder(customerId, items, specs)` and `OrderPickedUp = GoodSignal.new()` fired in `_handlePickUp` after a successful hand-over with `(customerId, baristaPlayer, grade, specs, tools)`. Inside `pcall`.
3. **Auto-dispatch.** Read `_tryDispatchFromQueue` and `_claimNextOrder`. If an order created by a customer is not already assigned to a free clocked-in barista without any claim action, add the assignment inside `_tryDispatchFromQueue`'s existing path (call `_claimNextOrder(barista)` for the clocked-in player with no active order who has been idle longest, re-run on `ClockedInChanged` and after each pick-up). If the existing queue code already auto-assigns, add nothing and say so in evidence. Keep the M1 rule that CustomerService waits while `GetPendingCount() > 0`.
4. **Bubble.** `RealOrderService` listens to `OrderCreated`; for the customer's character head, add a `BillboardGui` (STYLE 4.5 exactly; copy the layout of `Npc.luau buildBubble`) with text "Real customer!  ×2 pay" using only `Styles` tokens; remove it on pick-up, cancel or `PlayerRemoving`. Set it on the server so everyone sees it.
5. **Customer keeps the drink.** On `OrderPickedUp` give the drink tool(s) to the customer's backpack (they stay holdable; set the tool attribute `MadeBy = barista.DisplayName`, `Served = true` so `FindServeTools` never reuses them); do not destroy them. If `_handlePickUp` already hands the tool to the customer, add nothing.
6. **Customer rewards.** `StatisticsService:IncrementStat(customer, "RegularOrders")` (add the stat; this is the "Regular" stat). Quest hook (stub only; quests are M4): `local ok, quests = pcall(Knit.GetService, "QuestService")`; if it exists call `quests:Progress(customer, "RealOrder")` inside `pcall`; otherwise nothing.
7. **Barista pay.** Pure function `RealOrderService.PayMultiplier(history, baristaId, customerId, now) -> number` returns `PAY_MULT` while the barista has served that customer fewer than `BONUS_ORDER_COUNT` times in the last `WINDOW_SECONDS` (history in session memory: list of timestamps per pair), else 1. On `OrderPickedUp`: `pay = Rules.Payout(specs as items, grade, 0, 0, false, false) * multiplier` (fraction 0 means no fast bonus; combo 0), `CurrencyService:Modify(barista, "BobaBucks", pay)`, record the timestamp, toast the barista `+N · Real customer ×2` via `DialogService:Notify` (field `Text`). Spec: 3 orders in the window get ×2, the 4th gets 1, the 4th after 10 min gets ×2 again.
8. **XP.** `ProgressionService:AddXp(barista, 10 * #specs)` (the same `XP_PER_ITEM`; use `Progression.XP_PER_ITEM`).
9. `stylua` then `gate` on all changed files.

## Done when
- A clocked-out player's order reaches a free barista without them pressing claim.
- The bubble is visible to others and disappears on pick-up.
- Pay matches the spec cases; customer keeps the drink and `RegularOrders` increments.
- Gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (design exit: a 3-client test, run by Jack: two baristas plus one customer).

## STOP-AND-ASK
- Rating the barista with 1 to 5 hearts (design §4.9) and the ready-order beam are not in this packet's scope. Ask Jack if they are wanted in M2.
- `Rules.Payout` takes NPC order items; if player-order specs cannot be converted to that shape in two lines, ask Jack for the base pay of a player order.
- Whether hand-over destroys the tool in `_handlePickUp` and the customer expects to keep it: if the code path conflicts with step 5, ask Jack.

## Evidence
`tasks/REVIVAL-001/M2-REALORDER/evidence.md` (RUNBOOK step 5).
