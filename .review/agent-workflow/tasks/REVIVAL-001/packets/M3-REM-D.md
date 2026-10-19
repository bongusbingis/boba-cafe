# M3-REM-D: Double Storage pass (InventoryX2)
Model: sonnet   Studio: no   Depends on: M3-REM-B (built)   Size: M

## Goal
Players who own the Double Storage pass (14067346, perk `InventoryX2`) can hold twice as many items in each storage inventory. Everyone else is unchanged.

## Hard constraints
- Never run Play or TestEZ (DEC-019); Jack does that.
- Gate: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'` on every changed Luau file. No new Selene/StyLua findings in changed files (DEC-001).
- No economy value changes (prices, amounts, probabilities) beyond what the decisions listed say (DEC-036 B4, DEC-028 E20). Anything else is STOP-AND-ASK.

## Serve-path invariant (M3-REM-B)
Nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or in the RealOrderService payout. No new yielding calls (WaitForChild, task.wait, DataStore/MessagingService, remote InvokeClient, Promise:await, :Wait()) in those spans. This packet does not touch either file; the invariant also applies to the new storage-limit reads below, which must be synchronous.

## Money code
Capsule purchases (BobaBucks spends) sit next to the changed limit checks: a Sentry review follows the build (`tasks/REVIVAL-001/M3-REM-D-SENTRY/`).

## Already built (verified)
- Pass and perk: `PassCatalog.luau:28` `[14067346] = { Name = "Double Storage", Perks = { "InventoryX2" }, Listed = false, Legacy = true }`. No effect is wired: `grep InventoryX2` finds only that row. The M3-REM-B evidence calls it "a catalog row only (M3-REM-D)". `Perks.luau` has no entry for it (flag perks are not listed there).
- Pass perks are read through `PerkService:HasPerk(player, perk)` (PerkService.luau:45), which loops `PassCatalog` and calls `self:_hasPass` -> `GamepassUtil:PlayerOwnsPassAsync` (a yielding call on a cold cache; results are cached per player for the session and cleared on PlayerRemoving; nothing refreshes the cache after a mid-session purchase, as for every other pass perk). `PerkService:PlayerAdded` (:90) already calls `GamepassUtil:PrefetchAllPassesAsync(player)` to warm that cache. `PerkService:PlayerRemoving` (:97) clears per-player state. The loader at `server/init.server.luau:25-34` calls both hooks.
- Doubled value source: `revival-plan.md` section 6.3 table row "Double Storage (14067346) | off-sale | Inventory limit x2 (`InventoryLimits.luau`)". DEC-028 E20 approves "the defined mappings in revival-plan 6.3" and DEC-036 B4 = A sends Double Storage to this packet, so x2 is approved. `M3-ECON/answers.md` and DEC-036 contain no other storage number. They do not say which limit group is doubled or what happens on losing the pass (see STOP-AND-ASK).
- Current limits: `InventoryLimits.luau`: `BASE_STORAGE = RunService:IsStudio() and 200 or 10`; `Storage = { Nametags, Pets, Particles, Capsules }` all = BASE_STORAGE (10 live, 200 Studio); `Equipped = { Nametags = 1, Pets = 1, Particles = 5 }`. Doubled: 20 live / 400 Studio.
- The one reader function is `Utility.GetInventoryLimit(limitType, itemType)` (`shared/Inventory/Utility.luau:64`), called only from `InventoryServer.luau`: `_setEquipped` (:178, "Equipped", auto-unequips the first item) and `Insert` (:245, "Storage", returns nil with a warn when the count is at or over the limit). It is synchronous and has no player argument.
- Every other call site reads `InventoryLimits` directly (`require(Shared.Configuration.InventoryLimits)`), all in `CapsuleService.luau`, each comparing the current count with `limits.Storage.<Type>`:
  1. `CapsuleService:PurchaseNametagCapsules` (:204), `slots >= limits.Storage.Capsules` (:243) -> `false, "InventoryFull"`, before `TrySpendAsync`.
  2. `CapsuleService:PurchaseDeterministicNametag` (:289), `slots >= limits.Storage.Nametags` (:326) -> `false, "InventoryFull"`, before `TrySpendAsync`.
  3. `CapsuleService:HasCapsuleSpace` (:582), `countCapsules(inv) < limits.Storage.Capsules` (:589); sole caller `DailyRewardService.luau:144` (refuses the daily claim with "InventoryFull" when false).
  4. `CapsuleService:GrantEarnedCapsule` (:596), `countCapsules(inv) >= limits.Storage.Capsules` (:603) -> `"InventoryFull"`; callers include TreasureHuntService (chest capsule) and DailyRewardService.
  5. The starter-capsule handler in `CapsuleService:KnitStart` (the ShiftEnding connection, `capsuleCount >= inventoryLimits.Storage.Capsules` at :866) -> warn and skip.
  The count and the following `Insert` in sites 1, 2, 4 and 5 run without a yield in between; the limit must therefore be resolved before the count, never between it and the Insert.
- Paths that insert without their own check rely on the `InventoryServer:Insert` limit (:245): pet hatch completion (`completePendingHatches`, `petsInventory:Insert` :477; a failed insert keeps the hatch pending, `"RewardInsertFailed"`), instant non-pet capsule rewards (`StartHatch`, `inv:Insert` :658), `GroupBenefitService.luau:156` (pet grant), `PromoCodes.server.luau:93`, and the Studio-only `server/init.server.luau:55` grant-all. Pets and Particles have no CapsuleService check at all.
- Client display of the limit: none. `GetInventoryLimit` and `InventoryLimits` are not referenced under `src/client` or `src/shared/UI`; the only UI text is DailyRewardsDialog's InventoryFull toast ("Your capsule inventory is full - make room to claim today's reward!"), which stays correct.
- `GamepassUtil` is the only source of ownership; `STUDIO_PASSES_ENABLED = false` (GamepassUtil.luau:30) so in Studio ownership comes from the real `UserOwnsGamePassAsync`.
- Test seams: `PerkService.spec.luau` replaces `service._hasPass` and uses plain-table fake players; there is no spec for CapsuleService, InventoryServer or Utility.

## Design
The limit reads sit on synchronous paths (count then Insert), so the pass lookup must not run there. `PerkService` keeps a per-player storage multiplier that is resolved once after the prefetch and read synchronously everywhere. Until it is resolved (the first moments after joining) the multiplier is 1, which only ever blocks an addition, never allows an extra one (fails closed).

## Read (only these)
- `decisions.md` DEC-028 (E20), DEC-036 (B4); `revival-plan.md` section 6.3 row for Double Storage; `M3-REM-B/evidence.md`
- `src/server/Modules/PerkService.luau`; `src/shared/Configuration/Perks.luau`; `src/shared/Configuration/PassCatalog.luau`
- `src/shared/Configuration/InventoryLimits.luau`; `src/shared/Inventory/Utility.luau:55-75`; `src/shared/Inventory/InventoryServer.luau:170-260`
- `src/server/Modules/CapsuleService.luau`: the five sites above
- `src/server/Tests/PerkService.spec.luau` (fixture style only)

## Write scope
- `src/shared/Configuration/Perks.luau` (add `StorageMultiplier = 2` to the returned table, citing DEC-028 E20 / revival-plan 6.3)
- `src/server/Modules/PerkService.luau` (multiplier cache and sync getter)
- `src/shared/Inventory/Utility.luau` (optional multiplier argument)
- `src/shared/Inventory/InventoryServer.luau` (`Insert` only)
- `src/server/Modules/CapsuleService.luau` (the five sites)
- `src/server/Tests/PerkService.spec.luau` (new cases); `src/server/Tests/InventoryLimit.spec.luau` (new, pure `Utility` cases)
- Do NOT edit `InventoryLimits.luau` base values, `PassCatalog.luau`, `CustomerService/init.luau`, or `RealOrderService.luau`.

## Steps
1. `Perks.luau`: add `StorageMultiplier = 2` to the returned table (next to `PetTipBonus`) with a one-line comment: Double Storage (InventoryX2) doubles Storage limits, DEC-028 E20 / revival-plan 6.3. Update the file header comment only if it would otherwise be wrong.
2. `PerkService.luau`: add `_storageMultiplier = {} :: { [Player]: number }`. Add `function PerkService:RefreshStorageMultiplier(player)`: `self._storageMultiplier[player] = if self:HasPerk(player, "InventoryX2") then PerkConfig.StorageMultiplier else 1` (yields on a cold cache; never called from a count-then-insert span; guard with `player.Parent ~= nil` before writing so a departed player does not re-create an entry, the same bug as the `_tipRemainder` P3). Add `function PerkService:GetStorageMultiplier(player): number` returning `self._storageMultiplier[player] or 1` (synchronous, no yield, no Knit call).
3. `PerkService:PlayerAdded`: after the existing prefetch, chain the refresh without blocking: `PrefetchAllPassesAsync(player):andThen(function() self:RefreshStorageMultiplier(player) end)` inside the existing pcall style (the return is a Promise; do not `:await()` in the hook). `PerkService:PlayerRemoving`: also `self._storageMultiplier[player] = nil`.
4. `Utility.GetInventoryLimit(limitType, itemType, storageMultiplier: number?)`: when `limitType == "Storage"` and the multiplier is a number >= 1, return `math.floor(limit * storageMultiplier)`; `"Equipped"` is never multiplied. Keep the existing asserts. Existing callers and the client keep working unchanged (multiplier defaults to 1).
5. `InventoryServer.Prototype:Insert` (:245): resolve the multiplier with `local multiplier = 1` then `pcall(function() multiplier = require(Server.Modules.PerkService):GetStorageMultiplier(self.Metadata._player) end)` (module already cached; sync; failure leaves 1) and pass it as the third argument. Do not change the `Equipped` call at :178. Note in a code comment that `Server` is the existing `ServerScriptService.Server` local at the top of the file.
6. `CapsuleService.luau`: add one local helper near the top, `local function storageLimit(player: Player, itemType: string): number`, that does `require(Shared.Inventory.Utility).GetInventoryLimit("Storage", itemType, <PerkService:GetStorageMultiplier(player) via pcall(Knit.GetService, "PerkService"), default 1>)` (follow the file's existing `Knit.GetService` style; verify the exact module path of `Utility` and use whatever the file already requires for `Shared.Inventory`). Replace the five comparisons with `storageLimit(player, "Capsules")` or `"Nametags"` exactly where `limits.Storage.X` is read today; compare operators and error returns stay the same. The helper makes no yielding call, so the count-then-insert spans stay atomic. Remove the now-unused `InventoryLimits` requires only if nothing else in the file uses them.
7. Specs. `PerkService.spec.luau`: `GetStorageMultiplier` is 1 with no refresh; after `ownedPasses[14067346] = true` and `RefreshStorageMultiplier(player)` it is 2; releasing the pass and refreshing again returns 1; `PlayerRemoving` clears the entry; `RefreshStorageMultiplier` for a player whose `Parent` is nil (plain-table fakes have no `Parent`, so use a table with `Parent = nil` and one with a non-nil Parent stub) writes nothing. New `InventoryLimit.spec.luau` (pure): `GetInventoryLimit("Storage", "Capsules")` equals `InventoryLimits.Storage.Capsules`; with multiplier 2 it equals double; `"Equipped"` ignores the multiplier; a multiplier below 1 or non-number is ignored.
8. Run the gate.

## Done when
- A Double Storage owner can hold 2x the base storage in Capsules, Nametags, Pets and Particles through every add path (capsule purchase, nametag purchase, hatch, earned capsule, daily capsule, chest capsule, starter capsule, group pet, promo item); a non-owner is unchanged at the base value.
- Equipped limits are unchanged.
- No new yield exists between any count and its Insert; no file outside Write scope changed.

## Test for Jack (Play; Mason and Sentry never run Play)
Jack's Roblox account needs to own pass 14067346 for the owner cases (or test with a second account). To avoid collecting 10 or 200 items, temporarily edit `BASE_STORAGE` in `InventoryLimits.luau` to `3` locally and revert it before finishing.
1. Without the pass: buy nametag capsules until Capsules reaches 3; the next purchase is refused with an inventory-full message and no BobaBucks are spent. Same for nametags and a pet hatch (hatch stays pending, nothing lost).
2. With the pass (rejoin after buying; the pass cache is per session): the same actions succeed until 6 items, then refuse.
3. Claim a daily reward and open a chest capsule while at 3 (no pass) and at 4 (pass): refusal and success respectively, using the existing messages.
4. Equip rules unchanged: still 1 pet and 1 nametag equipped, 5 particles.
5. Over-limit case (the pass lost, see STOP-AND-ASK Q-D2): get 5 items with the pass, then (using a second account without the pass holding 5 items, or by testing with the multiplier forced to 1 temporarily) confirm nothing is deleted or hidden, existing items stay usable and sellable, and only new additions are refused until you are under the limit.
6. Join and immediately claim something in the first second: if the multiplier is not resolved yet, an addition is refused at worst (never over-granted); retry succeeds.
7. A pass bought mid-session takes effect after rejoin (same as every other pass perk); confirm this is acceptable.

## Checks to run
- The gate command above on each changed file. Never Play or TestEZ (DEC-019).

## STOP-AND-ASK
- PENDING JACK Q-D1 (scope of x2): revival-plan 6.3 says "Inventory limit x2 (`InventoryLimits.luau`)", and the file has two groups. Recommended A: double only `Storage` (what "Double Storage" and the DEC-036 B4 label say). B: also double `Equipped` (equip 2 pets instead of 1; a gameplay change that needs Jack). This packet implements A.
- PENDING JACK Q-D2 (pass lost while over the limit): no document answers this. Recommended A: never delete or hide items; the `count >= limit` checks already refuse only new additions until the count is under the new limit; existing items stay usable. B: anything else (grace period, forced selling) is a design choice for Jack. A pending hatch whose pet cannot be inserted stays pending and retries (existing behaviour). This packet implements A.
- Anything that would change a base limit value, a price, or the pass ID: stop.
- If `Utility` or `InventoryServer` cannot require `PerkService` without a load-order error (cycle), stop and report BLOCKED with the exact error; do not move the cache elsewhere on your own.

Evidence
`tasks/REVIVAL-001/M3-REM-D/evidence.md` (RUNBOOK step 5), including the "Test for Jack" list above.
