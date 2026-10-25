# M2-HEARTS: Customer rates the barista; beam to the ready order
Model: sonnet   Studio: no   Depends on: M2-REALORDER (done)   Size: S

## Goal
This is the rest of Q17 (approved, DEC-011). After a real player picks up their order, they can rate the barista 1-5 hearts with a single tap. While their order is ready, a beam guides them to the pick-up node.

## Read (only these)
- `tasks/REVIVAL-001/M2-REALORDER/evidence.md`
- `M1.2/design.md` §4.9 (lines 271-277)
- `src/server/Modules/RealOrderService.luau`: grep `OrderPickedUp`, `MadeBy`
- `src/client/Modules/KitchenGuidance.luau` and `KitchenController.luau`: grep `Beam` (reuse that beam code)
- `docs/STYLE.md` §3.5 and §4.2 (the dialog recipe)

## Write scope
- `src/server/Modules/RealOrderService.luau`
- `src/client/Modules/OrderController.luau`
- one new dialog type under `src/shared/UI/Components/Dialogs/`, copied from an existing ButtonPrompt (STYLE §4.2)

## Steps
1. On pick-up, the server sends the customer a hearts prompt (5 buttons, using the existing dialog pattern) that names the barista.
2. The customer's choice goes to the server through the existing remote pattern. The server validates it: an integer from 1 to 5, the customer owns that order, and only once per order. It adds the result to the barista's `Statistics.HeartsReceived` and `HeartsCount` (ProfileTemplate is NOT in scope, so write them through `StatisticsService:IncrementStat`, which creates missing keys; grep to confirm, and if it doesn't, add a STOP-AND-ASK line).
3. While the customer's order is "Ready for Pick Up", show the customer a beam to the pick-up node, reusing KitchenGuidance's beam builder. Remove it on pick-up.

## Done when
The gate passes.

## STOP-AND-ASK
- IncrementStat can't create new keys.

## Evidence
`tasks/REVIVAL-001/M2-HEARTS/evidence.md` (5 lines)
