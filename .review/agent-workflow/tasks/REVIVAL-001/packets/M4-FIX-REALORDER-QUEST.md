# M4-FIX-REALORDER-QUEST: customer's real order advances their RegularOrders quest
Model: sonnet (Mason, Studio: no; Sentry review after, money path)   Depends on: Q27 = A with RegularOrders (Jack: "your recs", 2026-10-20), DEC-051   Size: XS

## Goal
`RealOrderService:_onOrderPickedUp` (about lines 240-250) calls `quests:Progress(customer, "RealOrder")`. `QuestService` has no `Progress` method and no quest type `RealOrder`, so the `if quests.Progress` guard makes it a silent no-op. Make the CUSTOMER's real order advance their `RegularOrders` quest (the barista already does, about line 300), by calling `AdvanceQuest(customer, "RegularOrders", 1)` inside the existing pcall, same position.

## Serve-path invariant (M3-REM-B), mandatory
Nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. The tip bonus is resolved first and nothing after it may yield. This change replaces one non-yielding in-memory call (`AdvanceQuest` only reads/writes player data and fires a remote) with another at the same position. Do not add any wait, `GetService` outside the existing pcall, DataStore/ProfileStore, or MarketplaceService call. Do not move, reorder or touch pay, XP, history, self-serve guard or tip code.

## Write scope
`src/server/Modules/RealOrderService.luau` only (the quest call). Also the existing spec for RealOrderService if one already asserts the old `Progress` call (grep `src` for `"RealOrder"` and `Progress(`); update it minimally, do not write new tests that need Play.
Not touched: QuestService, QuestConfig, CustomerService, any client UI.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio. Do not commit.
- Keep `pcall`, nil-safety and the self-serve early return (no quest progress for your own order).
- Gate: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'` (no stylua if the file has DEC-001 drift; then gate alone, no new findings), plus `rojo build` to a path outside the repo.

## Test for Jack (Play, his Studio)
- Two players: A orders at the phone/register, B serves it. A's Regular Orders quest (if rolled) advances by 1; B's also advances (existing). Ordering for yourself (self-serve) advances nothing.
- Pay, XP, tip and the "Real customer" notice are unchanged.
