# M4-FIX-REALORDER-QUEST evidence

## Diff
src/server/Modules/RealOrderService.luau, `_onOrderPickedUp` (~line 245), same position inside the existing pcall:
- guard `quests.Progress` -> `quests.AdvanceQuest`
- call `quests:Progress(customer, "RealOrder")` -> `quests:AdvanceQuest(customer, "RegularOrders", 1)`
No spec referenced `"RealOrder"` or `Progress(` (grep of src), so no test changes.

## Gate
`stylua --check` exit 0; `gate src/server/Modules/RealOrderService.luau`: selene new=0 (baseline 0, now 0), stylua ok, rojo build PASS, GATE: PASS.
No Play/TestEZ run (per DEC-019).

## Serve-path invariant
The customer-side block runs before the pay/tip code and is unchanged in structure: one pcall'd in-memory call replaced by another. No wait, no new GetService (the existing `pcall(Knit.GetService, ...)` is untouched), no DataStore/ProfileStore/MarketplaceService call. Tip bonus resolution, pay, XP, history, self-serve guard and notice code are untouched. No yield point added between the serve guards and the payout.
