# M3-E24-REVIEW — first-shift capsule grant technical review

RESULT: PASS — E24 can be implemented with the existing durable `Inventory.FreeItemsRedeemed` field and inventory API; strict crash-atomic exactly-once semantics are not established by the inspected APIs.

## Scope and source state

- Task: `REVIVAL-001 / M3-E24-REVIEW`.
- Git HEAD: `cbf5271f506eee95c46b160c17d56a464af088ce`.
- Environment: read-only source inspection; no Studio, tests, or production-code changes.
- DEC-024 confirms E24: one free Regular Pet Capsule after the first shift, server-side, once, through the inventory API, while failure must not block completion or play (`.review/agent-workflow/decisions.md:5-14`).

## Verified facts

- `ShiftService:_beginShift` reads `Statistics.ShiftsCompleted`; when it is zero it configures the first-shift target. `_endShift` derives `first` from `state.Completed == 0`, resets/publishes the next state before any notifications, fires `ShiftEnding`, then increments `ShiftsCompleted` (`src/server/Modules/ShiftService.luau:121-209`). A `ShiftEnding` consumer can use `summary.First`; it is the public representation of the candidate's first-shift check.
- The profile template already contains both `Inventory.Items.Capsules` and the durable `Inventory.FreeItemsRedeemed` collection (`src/shared/Configuration/ProfileTemplate.luau:91-99`). This does not require a new profile-schema field.
- `PlayerSetup` uses `FreeItemsRedeemed` as a durable one-time marker: it checks for `"GroupPet"`, inserts the marker, then grants the item (`src/server/Modules/DataService/PlayerSetup.luau:80-95`). That pattern establishes the field's intended role but does not prove transactional behavior across the marker and inventory writes.
- `InventoryServer:GetPlayerInventoryAsync` resolves a per-type inventory. `Insert` validates its input, can return `nil` for validation or capacity failure, writes through `_writeRawItem`, rebuilds cache, emits an added notification, and returns an item id on its success path (`src/shared/Inventory/InventoryServer.luau:101-114`, `233-268`). `_writeRawItem` awaits profile access, so `Insert` is not a non-yielding synchronous primitive.
- `CapsuleService` already obtains an inventory asynchronously and calls `Insert` for capsule rewards (`src/server/Modules/CapsuleService.luau:95-112`, `160-193`). The inspected call sites do not check `Insert`'s returned id.

## Recommendation

1. Subscribe server-side to `ShiftEnding` and act only when `summary.First` is true. Start the reward flow asynchronously after the shift state has already been reset and published; its failure must be caught and logged, never propagated into `_endShift`.
2. In that flow, load profile data and first check `Inventory.FreeItemsRedeemed` for a stable marker such as `"StarterCapsule"`. If present, return without a grant.
3. Obtain the `Capsules` inventory through `Inventory:GetPlayerInventoryAsync(player, "Capsules")` and call `Insert` with the existing Regular Pet Capsule definition shape. Treat a rejected promise or a `nil` item id as a failed best-effort grant: log it and leave the marker absent.
4. Only after a non-`nil` insert id, persist `"StarterCapsule"` in `FreeItemsRedeemed`. This favors not silently losing a reward when inventory access or capacity rejects the insert. The implementation must re-check the durable marker in its same server-side grant routine before each attempt.

This uses an existing data field and the inventory API required by DEC-024. It does not alter the reward, timing, or purchase/economy behavior.

## Failure-mode assessment

| Failure mode | Observed behavior / recommendation |
|---|---|
| Shift completion errors after reset | Shift state is already reset before `ShiftEnding`; reward work must remain isolated so its failure cannot stall play. |
| Inventory acquisition rejects | Catch and log; do not write the marker, so the grant is not falsely marked complete. |
| `Insert` rejects or returns `nil` (including full capsule inventory) | Catch/log or return; do not write the marker. |
| Repeated signal or retried handler after marker persists | The durable marker suppresses another grant. |
| Process interruption between successful insert and marker write | The inspected APIs provide no atomic operation spanning the capsule insert and `FreeItemsRedeemed` marker. A later replay could duplicate one capsule. |
| Marker written before insert | Avoid: an insert failure would permanently lose the approved reward. The existing GroupPet ordering is precedent only, not proof that it meets E24's failure requirements. |

## Inference and remaining technical limit

The proposed post-insert marker ordering is the least harmful option supported by the inspected APIs: it preserves a player's eligibility after an observable failure and does not block play. It cannot prove strict exactly-once behavior through a server crash in the narrow interval after inventory insertion and before marker persistence. Conversely, marker-first ordering provides at-most-once behavior but can permanently lose the reward.

The inspected ranges do not expose a transaction or idempotency primitive that atomically writes both an inventory item and `FreeItemsRedeemed`. If strict crash-atomic exactly-once delivery is required, the smallest technical follow-up is an inventory/profile-level one-time grant primitive that owns both writes under one documented atomicity contract. This is a technical implementation gap; it does not require changing the approved reward. Whether the bounded duplicate-versus-lost-reward trade-off is acceptable is not decided by this review.

## Source hashes at review

All packet-listed source hashes matched the values at dispatch:

- `src/server/Modules/ShiftService.luau`: `42356AA72F9F1EB3E7B2ED6945121608AFFC23385B4B444A57D0CCE33F31471B`
- `src/shared/Configuration/ProfileTemplate.luau`: `7F01385E5FF0A388AF0717AF5B47E4A1CA5DAADB0EB1A565F39CE01D889F702B`
- `src/server/Modules/DataService/PlayerSetup.luau`: `994D9C7084196CE11B5E2A9E9F2605C7C5FB87A16687F3D6B563124DB344DFBB`
- `src/shared/Inventory/InventoryServer.luau`: `CD4E9EA6F24A7EE0EEF5BB2CA3175668E465B935270649AC94E833CE4232CC35`
- `src/server/Modules/CapsuleService.luau`: `38B920EEE2F9C6583CEEA8C40A53E7740EB1897E537F4DFA4F8FF7D03021DF43`

## Checks

- Read-only line inspection of the files and ranges named by `packets/M3-E24-REVIEW.md`.
- SHA-256 comparison against the packet's dispatch hashes: all five matched.
- Not run: tests, Studio, runtime behavior, or app edits, as required by the packet.

## Unverified

- The actual persistence/transaction semantics of `DataService:SetValue` across separate inventory and marker writes.
- Runtime ordering of multiple `ShiftEnding` subscribers and behavior during player departure/server shutdown.
- The exact `Regular Pet Capsule` item-root input required by the current inventory definition, because the packet did not authorize inspection of its definition file.
