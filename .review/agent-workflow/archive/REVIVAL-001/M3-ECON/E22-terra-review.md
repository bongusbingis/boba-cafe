# E22 Terra durability review

- Review mode: independent source review only. No Studio, Play, TestEZ, formatter, gate, or production-source edits by Terra.
- Reviewed working-file hashes: `PlayerSetup` `3abb9a48664bef5950a456b63856743c7fa7f820`; `GroupBenefitService` `11daa73183e1e6a41e8f86cb86d04b9662bc344b`; `Shop/init` `5cffee48373d7cbc7d548959f1b8c83932b03f9e`; `Shop/GroupBenefit` `9d34d73ced82a2accb8d56325162028dc739f39e`. Each matches the E22 evidence snapshot.
- RESULT: **FAIL**.

## Blocking finding: uncoordinated whole-list writes lose other redemptions

`GroupBenefitService` takes `redeemed = playerData.Data.Inventory.FreeItemsRedeemed` at line 100, then yields for `IsInGroupAsync` and multiple `SaveAsync` calls. It subsequently writes full tables derived from that stale value at lines 113-116, 155-162, and 169-174. Its per-user `claimsInProgress` guard only serializes callers of this service; it does not serialize other writers of `FreeItemsRedeemed`.

`CapsuleService` independently writes the same whole list for `StarterCapsule` on first ShiftEnding (`CapsuleService.luau:693-724`). A concrete interleaving is:

1. Group claim reads `[]` and yields for membership verification.
2. Starter reward writes `[StarterCapsule]` and inserts its capsule.
3. Group claim resumes and writes `[GroupPetPending:<guid>]` from its stale clone, erasing `StarterCapsule`.

The group intent save predicate only checks that its pending ID exists in `Profile.LastSavedData`; it does not require preservation of existing list entries or compare against a version. It can therefore confirm and grant the Ant Pet after silently losing the StarterCapsule redemption marker. A later shift can grant the starter capsule again. The same lost-update hazard exists when group finalization/rollback replaces the list while another writer runs. This fails the requirement to prevent lost claims and makes the durability protocol unsafe under the requested concurrency scenario.

The repair needs a shared per-player/profile mutation mechanism for all `FreeItemsRedeemed` writers, or a mutation API that re-reads and merges the current list immediately before every write and confirms the complete intended state. `SaveAsync` confirmation alone is not a compare-and-set transaction and cannot prevent this overwrite.

## Confirmed parts

- Within the isolated GroupBenefit claim flow, the unique pending ID and `Properties.GroupPetClaimId` provide a sound correspondence: retry looks up the exact tagged Ant Pet before inserting, then only finalizes when a saved snapshot contains the pending marker and matching tagged pet.
- `InventoryServer:Insert` persists supplied item properties in the profile-backed inventory record, so the tag is available to the service's `GetProperty` retry lookup.
- `DataService:SaveAsync` correctly waits for an `OnAfterSave` snapshot satisfying its predicate, and returns false on inactive profile or timeout. Its predicates establish that a qualifying snapshot was saved; they do not serialize, reserve, or preserve concurrent profile mutations.
- The local `claimsInProgress` guard covers concurrent claim remotes in one server. Removing the old PlayerSetup auto-grant prevents that former duplicate path. The UI only sends a claim after a user-initiated join result and the server rechecks membership.

## Unverified

- No Studio/runtime verification of ProfileStore save ordering, `OnAfterSave` behavior during overlapping saves, Roblox group membership prompt, profile restart, full inventory, or cross-server recovery.
- This review found `StarterCapsule` as the current other `FreeItemsRedeemed` writer; future writers have the same hazard unless they share the mutation contract.

## Next

Repair the shared-list concurrency contract, then independently test Group claim and StarterCapsule simultaneously in both orderings, interruption after intent/pet/final marker saves, retry after restart, and a full pet inventory.

---

## E22 merge-fix re-review

- Review target: `src/server/Modules/GroupBenefitService.luau` blob hash `d0202725ed4b0dbac05af2a7879c409fd9c5a057`. The other three source hashes remain the values recorded in `E22-evidence.md` and the preceding review.
- Review mode: source-only follow-up. No Studio, Play, TestEZ, formatter, gate, or production-source mutation by Terra.
- RESULT: **PASS** for the prior stale-list and rollback finding.

### Findings

- The prior lost-update interleaving is repaired. After `IsInGroupAsync` yields, pending intent is composed from `playerData.Data.Inventory.FreeItemsRedeemed` immediately before `SetValue` (`GroupBenefitService.luau:122-138`). The Group flow therefore retains a `StarterCapsule` marker written while membership was being checked.
- Finalization performs the same live-list merge after the pet-save yield (`:176-187`), retaining a marker written by StarterCapsule while GroupBenefit waits for durable pet confirmation.
- Failed finalization no longer restores an old snapshot. Its rollback re-reads the live list, removes only the GroupPet marker that this invocation added, and restores its own pending ID (`:195-210`). This retains unrelated markers such as `StarterCapsule`.
- The remaining StarterCapsule write itself reads its list after all of its own awaits and performs its mark/insert sequence synchronously (`CapsuleService.luau:693-724`). Its normal successful path cannot reintroduce the old stale-snapshot overwrite. If its insert returns nil, its immediate rollback returns to the list it just read, which retains a Group pending ID if it observed one; no Group finalization can interleave inside that non-yielding mark/insert-failure sequence. No lost successful StarterCapsule claim or duplicate Group pet follows from the inspected interleavings.
- `findTaggedClaimId` also lets GroupBenefit recover a durable tagged Ant Pet whose pending list marker was removed by an older interrupted write, before it chooses a new GUID (`GroupBenefitService.luau:45-65,127-138`).
- `DataService:SaveAsync` remains a save-observation mechanism, not a transaction, but that is sufficient for these single-threaded live-list merge points: each group write reads the current profile value with no intervening yield, and ReplicaService's `SetValue` updates that value synchronously.

### Evidence and limits

- The working `GroupBenefitService` hash matches the specified merge-fix blob. The E22 evidence documents the intended pending-ID, tagged-pet, and predicate-save sequence; the M3-ECON packet and current `FreeItemsRedeemed` search show StarterCapsule as the relevant concurrent writer.
- Runtime persistence, ProfileStore overlapping-save behavior, server shutdown, full inventory, join prompt, and cross-server recovery remain unexercised. This PASS supersedes only the stale-list blocking finding above; it does not convert those runtime assumptions into test evidence.

### Next

Run the planned runtime scenarios: Group claim and StarterCapsule in both orders, StarterCapsule insert failure during Group finalization, interruption after each durable checkpoint, restart/retry with only the tagged pet, and a full pet inventory.
