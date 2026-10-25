RESULT: PASS
Changed: CapsuleService (HasCapsuleSpace, GrantEarnedCapsule), DailyRewardService, TreasureHuntService, QuestService, OrderService, RealOrderService (all in src/server/Modules).
Gate: GATE: PASS (selene new=0, stylua ok, rojo build ok) on all 6 files.
5c: unreachable after 5a. A barista can no longer be assigned their own order, so they can't deposit for themselves; no code change to _handlePickUp. 5a also applied in _handleClaimOrQueue so a barista with only their own order joins the queue.
Client: see grep output in report; client files not edited. Daily capsule days now return "InventoryFull" with nothing changed.
Stale specs (outside write scope, not run): DailyRewardService.spec / TreasureHuntService.spec fake InventoryServer.AddItem and _getInventoryServer; they need to fake CapsuleService.HasCapsuleSpace/GrantEarnedCapsule via _getService. QuestService.spec unaffected API-wise.
Test for Jack:
1. Solo, clocked in, order a drink: it must not be assigned to you; no real-customer pay/XP/quest.
2. With a second player: they serve you, they get paid normally; you get nothing extra.
3. Fill Capsules, claim a capsule daily day: "InventoryFull", streak/BB unchanged; free a slot, claim works.
4. Open a chest with full Capsules: BB granted, no capsule, no error. With space: capsule hatches for a policy-restricted player.
5. Reroll a quest while claiming it: never both paid and replaced.
Question for Jack: client friendly text for "InventoryFull" (see grep).
