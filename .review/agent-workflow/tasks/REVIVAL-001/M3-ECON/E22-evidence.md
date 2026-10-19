RESULT: PASS — Terra's durability and interleaving findings repaired; focused static gate complete; independent review/runtime verification remain open.

# REVIVAL-001 M3-ECON E22 evidence

- **Task:** E22 Group Benefit
- **Decision:** DEC-029 approves the existing one-time Ant Pet as the sole non-tip group benefit, with an explicit user-initiated join prompt and server-side membership recheck/claim.
- **Source state:** branch `uhweifh`, base commit `cbf5271`; existing unrelated dirty source/docs/evidence were preserved. Relevant files were already dirty before the original E22 task: `Shop/init.luau` had a one-line StyLua spacing change, which remains intact. Git blob hashes after the durability repair:
  - `src/server/Modules/DataService/PlayerSetup.luau`: `3abb9a48664bef5950a456b63856743c7fa7f820`
  - `src/server/Modules/GroupBenefitService.luau`: `d0202725ed4b0dbac05af2a7879c409fd9c5a057`
  - `src/shared/UI/Pages/Shop/init.luau`: `5cffee48373d7cbc7d548959f1b8c83932b03f9e`
  - `src/shared/UI/Pages/Shop/GroupBenefit.luau`: `9d34d73ced82a2accb8d56325162028dc739f39e`
- **Environment:** Windows checkout driven through WSL shims at `.review/agent-workflow/tools/wsl/env.sh`.

## Changes

- Removed the automatic group-membership pet grant from `PlayerSetup`; existing `Inventory.FreeItemsRedeemed.GroupPet` data is left unchanged.
- Added `GroupBenefitService` with a persistent claim-status query, per-user concurrent-claim guard, server-side `IsInGroupAsync(3174578)` recheck, and inventory API insertion of only the existing `Ant Pet`.
- **Terra durability and interleaving repairs:** `DataService:SaveAsync(player, predicate)` in `src/server/Modules/DataService/init.luau` confirms against `Profile.LastSavedData` and returns `false` if the save is not confirmed within its timeout. Before insertion, the service writes a unique `GroupPetPending:<GUID>` value into the existing `FreeItemsRedeemed` string list and requires a confirmed save containing that value. The same GUID is written to the Ant Pet's `Properties.GroupPetClaimId`. The service confirms a saved snapshot containing both the pending value and tagged pet before replacing the pending value with `GroupPet`; it then confirms a snapshot containing the final marker and tagged pet with no pending value. On retry after interruption/restart, it reuses the pending GUID and searches pet inventory for that exact property; if found, it finalizes without reinserting, and if no pending marker remains but a tagged pet exists, it recovers that pet's claim ID and restores the pending intent before proceeding.
- Every `FreeItemsRedeemed` write now clones the live profile list immediately before its synchronous `SetValue`: pending intent is composed after the membership yield; finalization is composed after the pet-save yield; rollback is composed after the final-save yield. Rollback removes only the marker this claim added and restores its pending ID while retaining unrelated current markers such as `StarterCapsule`. Failed intent save never inserts; failed inventory lookup/full inventory/insertion leaves the claim retryable.
- Added a persistent Shop tab/page. Its button calls `GroupService:PromptJoinAsync(3174578)` directly from the click handler and calls the claim remote only for `Joined` or `AlreadyMember`. Pending/declined/error states retain the prompt; the UI hides it only after the server reports `Claimed`.

## Checks

Original E22 static gate (four Luau files) was run before Terra's finding. After the repair, exact focused command:

```sh
wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua src/server/Modules/GroupBenefitService.luau && gate src/server/Modules/GroupBenefitService.luau'
```

- Follow-up StyLua: pass for `GroupBenefitService.luau`.
- Follow-up Selene gate: zero new findings in `GroupBenefitService.luau`.
- Rojo build: pass; output `.rbxl` written outside the repository to the configured temp directory.
- Studio, Play, and TestEZ: **NOT RUN**, as required by the assignment.

## Unverified behavior and risks

- Roblox join-prompt status handling, server membership recheck, persistence, full-pet-inventory retry, and UI rendering/interaction were not exercised in Studio or Play.
- Durable recovery and interleaving semantics are established by source inspection of the existing DataService save-confirmation contract and synchronous live-list updates; forced interruption, concurrent `StarterCapsule` grant, DataStore failure, and cross-server recovery were not runtime-exercised.
- The E22 source state still needs Terra's confirmation that the P1 finding is resolved before runtime validation or broader milestone closure.
