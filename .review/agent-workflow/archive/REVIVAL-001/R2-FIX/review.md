RESULT: PASS

# R2-FIX: Sentry re-review (read-only)

Scope: working-tree diff of 6 files in `src/server/Modules`. No CONFIRMED P1/P2 remains.

## Finding status

- P1-1 CLOSED (CONFIRMED by trace).
  - `_getNextOrder(excludeCustomerId)` skips own orders. It is used by `_claimNextOrder`, `_handleClaimOrQueue`, and the auto-assign filter.
  - `_tryDispatchFromQueue` no longer pops a barista whose only pending order is their own. They keep their queue slot (`queueIndex += 1`), and invalid baristas are still removed. The loop terminates because every iteration either removes or increments.
  - 5c: the staff path sets `OrderOwner = playerOrder.customer`. With (a), `preparedBy ~= customer`, so the customer-path pickup of your own prepared order is unreachable.
  - Backstop: `RealOrderService:_onOrderPickedUp` returns early when `barista.UserId == customerId`. Both ids are numeric UserIds (`OrderPickedUp:Fire(player.UserId, barista, ...)`), so the types match.
- P2-1 CLOSED (CONFIRMED). Both shims and the `hasPass` shim are removed. Capsules are inserted with `RandomSource = "FreeEarned"` through `GrantEarnedCapsule`, the only value `StartHatch` accepts to skip the paid-random policy.
- P2-2 CLOSED (CONFIRMED).
  - `ClaimReward` calls `HasCapsuleSpace`, then `GrantEarnedCapsule`, and only then writes `Streak`, `LastClaimTime` and BB. A full inventory returns `InventoryFull` with nothing consumed.
  - `claimsInProgress` is held across the yields.
  - `GrantEarnedCapsule` never throws: the inventory fetch is in a pcall, the insert and count are in a pcall, and failures return false.
  - The chest keeps its BB, and a pcall wraps the grant.
- P3-1 CLOSED (CONFIRMED).
  - One `questLocks` table covers Claim and Reroll. Every path after the lock is taken is inside the pcall, and the lock is released after it. `PlayerRemoving` clears it.
  - After the `TrySpendAsync` yield, the slot is re-read. If it is Completed or Claimed, the 50 BB is refunded once (`charged` is set only after a successful spend) and the function returns. The free-reroll path has no yield, so it needs no refund.

## New issues

- PLAUSIBLE, low: in `ClaimReward` the capsule is inserted before the `SetValue` calls. If `SetValue` threw (not expected), the player would keep the capsule and the streak would not advance, so a retry would grant a second capsule. A `CurrencyService:Modify` throw comes after the streak write, so it is not affected. No fix required.
- Note: the client has no confirmed friendly text for `InventoryFull`. I did not inspect it (the packet says not to edit client files). It is a failure return, not a kick, so there is no continued-play violation.
- P3-2 remains open, as the packet intends.
