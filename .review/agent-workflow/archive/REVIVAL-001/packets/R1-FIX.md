# R1-FIX: Repair Sentry R1 findings (deposit path, NPC seating, robustness)
Model: sonnet   Studio: no   Depends on: none   Size: M

## Goal
Baristas can't get stuck on orders that can't be made, can't overwrite another barista's pick-up, and NPCs don't sit on chairs. If a previous run left partial edits, the files below may already contain some of these fixes. Check before you change anything.

## Read (only these)
- `R1/review.md` lines 31-47 (the findings table)
- `M1.2/design.md` lines 382-410 (§7 launch menu; Q12 is approved, DEC-011)

## Write scope
- `src/server/Modules/OrderService.luau`, `src/server/Tests/OrderService.spec.luau`
- `src/shared/Ordering/Menu.luau`, `src/shared/Ordering/OrderSpec.luau`
- `src/client/Modules/OrderController.luau`
- `src/server/Modules/CustomerService/init.luau`, `.../CustomerService/Npc.luau`, `src/server/Tests/CustomerService.spec.luau`
- `src/server/Modules/KitchenService/InteractionRunner.luau`

## Steps
1. **P1-1.**
   - Add a launch allowlist (§7) as data in Menu.luau, plus a helper.
   - `CreateOrder` refuses items that aren't on it.
   - Clocking out (and leaving) returns that barista's "Being Prepared" orders to the queue.
2. **P1-2.**
   - The server refuses a deposit into an occupied pick-up node, with a friendly reason through the existing Announcement path.
   - OrderController hides the deposit prompt on occupied nodes, using the node's owner value.
3. **P2.** In Npc.luau: `humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)`.
4. **P3-6.** InteractionRunner: if the held tool changed during a dialog yield, abort the interaction without marking anything.
5. **P3-7.** Set the `NPC`↔`Default` collision pair to collidable, explicitly.
6. **P3-8.**
   - pcall the barista count in the pacing loop, with a throttled warn.
   - Protect the `_watchPlayer` loop.
   - Bound Menu's `WaitForChild("SelectorModels")` only if it's a small, local change.
7. **P3-9.**
   - Deposits set `tool:SetAttribute("Served", true)`.
   - Serve matching ignores tools that are already Served.
8. **Specs**, only for: off-menu refusal, occupied node, Served re-deposit, clock-out release.

Not in this packet:
- P3-4: accepted as designed.
- P3-5: handled by Q14-GATES.

## Done when
The gate passes (RUNBOOK step 3).

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/R1-FIX/evidence.md` (5 lines)
