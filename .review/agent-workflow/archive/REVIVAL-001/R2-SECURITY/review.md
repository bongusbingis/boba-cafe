RESULT: FAIL

# R2-SECURITY: Sentry review (read-only)

Scope: the client-callable remotes changed since `cbf5271`, plus the DEC-031 refund path, reviewed in the working tree
(the checkpoint `f06a9bf` plus Prime's D1 corrections). Per DEC-017, this reports only exploits, money or data loss,
duplicate grants and continued-play violations. DEC-033 has no entry in `decisions.md`, so it was not reviewed against.

FAIL is driven by P1-1. Nothing here allows unbounded currency minting, and no duplicate grant was found on the DEC-031 path.

## CONFIRMED (traced through code)

### P1-1: Solo self-serve farms the "real customer" pay, XP and the "Serve Real Players" quest
- `OrderService.luau:906-973` (Client:CreateOrder) has no check that the customer is not clocked in.
- `OrderService.luau:557-570` and `:631-680` (`_claimNextOrder` and the auto-assign in `_tryDispatchFromQueue`) never exclude `order.customer == staff.UserId`.
- `OrderService.luau:708-776` (`_handlePickUp`): a player deposits into a free node (staff path, owner becomes self), then triggers the same node again (customer path).
- `RealOrderService.luau:201-249` then pays that same player ×`PAY_MULT` (2) BobaBucks, XP, `AdvanceQuest(barista,"RegularOrders")` ("Serve %d Real Players", 75 BB / 40 XP) and `Progress(customer,"RealOrder")`.
- Scenario: one player alone in a server, clocked in, orders a drink, gets auto-assigned their own order, makes it and serves it. They are paid at the doubled rate, the real-player quest completes without another player, and they keep the drink tool. `_history` is wiped on PlayerRemoving (`:266-273`), so rejoining resets the 3-order ×2 window.
- Fix: in `_tryDispatchFromQueue` and `_claimNextOrder`, skip orders whose `customer == staffId`, and/or have RealOrderService pay nothing when `barista.UserId == customerId`.

### P2-1: Earned Daily and Treasure capsules are policy-gated as paid-random and can't be hatched
- `DailyRewardService.luau:27-39` tags capsules `RandomSource = "DailyReward"`; `TreasureHuntService.luau:15-29` tags them `"Free"`. Whichever module loads first installs the `InventoryServer.AddItem` shim; there is no native `AddItem`.
- `ItemActions.luau:13` passes that property through, and `CapsuleService.luau:575-580` (`StartHatch`) allows only `"FreeEarned"` to skip `GetPaidRandomPolicy`.
- Scenario: a PolicyService-restricted player claims Day 4 or Day 7, or opens a chest that rolls a capsule. The capsule can never be hatched. The same happens for every player whenever `GetPolicyInfoForPlayerAsync` errors. This contradicts DEC-029 E16, under which free earned capsules are the restricted players' path.
- Fix: tag both shims `RandomSource = "FreeEarned"`, and move the shim into one shared place so load order can't change the tag.

### P2-2: Daily and Treasure capsule rewards are silently lost when the inventory is full or the insert fails
- `DailyRewardService.luau:172-186` writes the streak and `LastClaimTime` and grants BobaBucks before `AddItem`. The return value is ignored, and a throw becomes `"InternalError"` after the streak is already consumed.
- `TreasureHuntService.luau:282-286` ignores the result too.
- Scenario: a player with a full Capsules inventory claims Day 7 (the Rare Pet Capsule). The streak advances, and the capsule is gone with no retry.
- Fix: check capacity before committing the claim, or on failure record a pending-capsule marker and retry it the way the Ant Pet claim does. At minimum, return a failure before writing the streak when Capsules is full.

### P3-1: Quest reroll racing a claim can pay out and replace the same quest
- `QuestService.luau:236-312`: `RerollQuest` yields in `TrySpendAsync` (`:281`). Claim and reroll use separate locks (`claimsInProgress` and `rerollsInProgress`), and `activeQuests` is read before the yield.
- Scenario: progress completes the quest during that yield, and `ClaimQuest` pays the reward. The reroll then overwrites the slot with a fresh quest, giving one extra quest's reward per reroll. The timing window is narrow, so the impact is low.
- Fix: share one per-player lock between `ClaimQuest` and `RerollQuest`, or re-check `Completed`/`Claimed` after the spend.

## PLAUSIBLE (not fully traced)

### P3-2: A capsule stack update that throws after mutating could double-grant
- `CapsuleService.luau:248-271` (and the same shape at `:332-354`).
- If `SetStackCount` mutates the stack and then throws (for example in replication), the verify read sees `previousCount + pack.Count`, so `granted` is true and nothing doubles. If the mutation lands only partially, the fallback `Insert` adds a second stack after the charge.
- This depends on `InventoryServer` internals that were not traced. Fix: on a stack-path failure, re-read the count and refund instead of falling back to `Insert`.

## Verified OK (no finding)

- **DEC-031 refund.** The obligation is recorded (`:185-188`), save-confirmed by predicate, then credited together with `BobaBucksSpent` and confirmed again (`:97-149`).
  - It is retried on join (`:742-754`) and before each purchase, always inside `withPlayerTransaction`, so settles never run in parallel.
  - A failure after the credit leaves `Pending = 0`, so there is no double credit. Matches DEC-031.
- **Prime's revert of the `playerTransactions` clear in `PlayerRemoving`** is correct.
  - `DataService:GetDataAsync` (`init.luau:123-133`) parks waiters on `OnLoadSignals[UserId]`, and they resume on the next load for the same UserId.
  - A stale transaction therefore resumes against the rejoined profile and must keep holding the lock to serialise against the new session.
- **Pickup distance-check removal** (`OrderService:_handlePickUp`): the call is reached only from the pick-up node's `ProximityPrompt.Triggered` (`:1045-1047`). See UNVERIFIED.
- **Other remotes:**
  - Purchase arguments are validated: pack size against a whitelist, `TrySpendAsync` atomic with no yield between read and write.
  - DailyReward has a claim lock and a server clock.
  - `EventService.Client:StartEvent` checks rank or the server-set `IsAdmin` attribute, with a debounce and cooldown.
  - The GroupBenefit two-phase claim, the Treasure claim flag (set before any yield, with a server distance check) and the Shift toggle debounce hold up.
  - `BadgeService.Client:AwardBadgeByName` allows only "Slipped".
  - The Kitchen, Spill and Customer services added no new client-invokable methods.
- **Boba Party.** The receipt slot is inert while `BOBA_PARTY_PRODUCT_ID` is nil. When it is configured, `StartOrExtendBobaParty` always returns true, so no receipt is lost. The new `BobaPartyCooldownEndsAt` attribute is display-only.

## UNVERIFIED
- That Roblox enforces `MaxActivationDistance` server-side for a prompt that is `Enabled = false` on the server and only enabled on the client. The pickup path relies on this.
- `InventoryServer.Prototype:Insert` and `SetStackCount` failure semantics (P3-2).
- Nothing was run (DEC-019: no Studio or TestEZ).

## Reviewed file hashes (git hash-object, working tree)
```
36d5735600f30a3f3847ac63b6dac685e2a2244b  src/server/Modules/CapsuleService.luau
15a748c1fbff960e67adacc8b4b64435a18718a5  src/server/Modules/DailyRewardService.luau
cdb4b83eb563394a441d97264ead1f3a312e200a  src/server/Modules/QuestService.luau
ed5d101ffb5b6ae50674bc4789e68dac7d03a7f3  src/server/Modules/EventService.luau
d0202725ed4b0dbac05af2a7879c409fd9c5a057  src/server/Modules/GroupBenefitService.luau
ad0c14fa8d2e23d03d30343aff1a3886a019d64e  src/server/Modules/TreasureHuntService.luau
59b356d211d4743ba215443843a7dd289157b18d  src/server/Modules/ShiftService.luau
84549602f4e85b9accbd0f7536222e343205b231  src/server/Modules/OrderService.luau
8ec3f057ee855136d0fbfff1a7c3f651407ec829  src/server/Modules/RealOrderService.luau
dc392fe54fd56caefc9e4fd6860a3409d174e093  src/server/Modules/CustomerService/init.luau
1975b6a83ec5d4fec61a1ddb8972c3ba9dcc5ec9  src/server/Modules/KitchenService/init.luau
e7f0ad81adec80097a325e5c49e76bc93440ce41  src/server/Modules/KitchenService/InteractionRunner.luau
4b7810d2cd52600f50540d15840bfca768c0da27  src/server/Modules/SpillService/init.luau
7839c788e4048d4aa15acf16f091688e6f40449f  src/server/Modules/BadgeService.luau
72f11f6086975f6c885428722e8cda9f93530f14  src/server/Scripts/ProcessReceipt.server.luau
e9457373d56e14bc3a89cec3efa9b2b3846e6ab6  src/server/Modules/CurrencyService.luau
a518e64719cb5f8d405d52e8169c98891087129e  src/server/Modules/DataService/init.luau
e835258ff1b4aba8c875a5e38170079cb6b71a62  src/server/Modules/CafeRatingService.luau
d359ab0c1938956135dd74d5d1288ff7b04d1a0b  src/shared/Inventory/ItemActions.luau
```
