# Terra review — M3-BULK-NAMETAG

- Date: 2026-10-17
- Review type: read-only technical escalation; no tests run and no source edits made by Terra.

## Blockers

1. `CapsuleService.completePendingHatches` is outside the per-player transaction. The ready-hatch client request and periodic server loop can race, grant duplicate pets, or clear a pending hatch when `petsInventory:Insert` fails. Serialize completion and retain pending state until the pet insert succeeds.
2. Refund recovery has no durable obligation record. If the bounded refund attempt cannot access/write the profile, only a server warning and player support message remain. Refund also does not reverse the `BobaBucksSpent` statistic. Define and implement a recovery/accounting policy before paid BB capsule sales ship.
3. The 10-pack had the “Best Value” banner despite 135 BB per capsule; the 50-pack is 120 BB each. Prime moved the banner to the 50-pack after review.

## Verified safe/correct parts

- Nametag hatch inserts the reward before consuming; on capsule-consumption failure, it rolls the new reward back.
- Purchase paths serialize, re-resolve and verify existing stacks after spending, then insert or refund if needed.
- Paid-random policy checks fail closed; explicitly `FreeEarned` first-shift capsules remain openable when policy lookup is unavailable. Unknown/legacy provenance is treated as paid for restricted users.
- Restricted users route to deterministic Nametag purchases, and the server rechecks policy. Current displayed Nametag odds match `CapsuleUtil`'s tier-weight roller.

## Remaining inference/risk

- `InventoryServer`'s arbitrary `removeItems` request is independent of the purchase transaction lock. The purchase re-resolution/verification handles the reviewed remove-while-spending case, but runtime concurrency remains untested.
- If a free Nametag source is added later, do not merge it into a `Paid` stack; no free Nametag source exists now.

## Recommendation

Do not proceed to Jack's runtime validation until pet completion serialization/insertion handling and durable refund/accounting are addressed. No project or human approval is granted by this review.

## PET-COMPLETION repair review

- Review target: `src/server/Modules/CapsuleService.luau` SHA-256 `B094B2EECBA7201E44E8CF0E305C5E037D9A6B41AFC7BA6F36DB95AC031650E9`.
- Review mode: source-only; no Studio, Play, TestEZ, gate, formatter, or production-source mutation by Terra.
- RESULT: **FAIL**.

### Blockers

1. The durable recovery scan cannot read the durable tag. `completePendingHatches.findHatchPet` reads `item.Properties` (`CapsuleService.luau:363-370`), but `InventoryServer:GetPlayerInventoryAsync` populates `Inventory` with `InventoryItem` wrappers (`InventoryServer.luau:288-306`). Those wrappers expose `GetProperties()`/`GetProperty()` and do not contain a public `Properties` field (`InventoryItem.luau:70-79`). Therefore a pet that was written when `Insert` later throws or returns nil is never found by the reload/retry scan. The first attempt keeps the hatch pending, but a later retry rolls and inserts a second reward before clearing it. This fails the requested post-write throw/nil recovery and can duplicate a reward. Read the tag through `item:GetProperties()` (or `item:GetProperty("CapsuleHatchId")`) and add focused coverage for the post-write failure case.

2. The receipt-based Skip Hatch path overwrites the entire pending record without `HatchId` (`ProcessReceipt.server.luau:77-80`). If it runs after a post-write insert failure, it changes the identity before retry; even a repaired recovery scan can no longer match the already-written tagged pet and may grant another. The replacement must preserve `HatchId` (and the existing `MinTier` field) when advancing the timer.

### Confirmed parts

- The new per-player transaction wraps the completion body across its awaits (`CapsuleService.luau:313-445`), so simultaneous client and periodic completion calls cannot both grant while the lock is held. A second call returns `TransactionPending` without mutating the hatch.
- A standard failed/full/invalid pet `Insert` leaves `HatchingPet` intact because the clear at line 432 is after the successful/recovered reward check.
- Item property serialization is structurally sound: `InventoryServer:Insert` deep-clones supplied `Properties`, `_writeRawItem` writes the raw item to `Inventory.Items.Pets`, and a reloaded wrapper reads the same raw `Properties` through `GetProperties()` (`InventoryServer.luau:99-109,252-268,275-306`; `InventoryItem.luau:70-79`). This supports `CapsuleHatchId` persistence once the scan uses that accessor. Runtime datastore persistence remains unexercised.
- New hatches receive a GUID at creation, ready legacy hatches receive one before their first grant attempt, and `flushAccumulatedTime` carries `HatchId` and `MinTier` forward (`CapsuleService.luau:345-353,459-464,565-570`). These paths preserve identity, subject to the receipt overwrite above.

### Unverified and residual risks

- No runtime proof covers an `Insert` that writes then throws/returns nil, profile reload, property replication, receipt timing, or concurrent client/periodic calls.
- `ProfileTemplate.PendingHatch` is still typed without `HatchId`/`MinTier`; current production accesses use `any`, so it does not reject this code, but the durable schema contract is stale and future typed writes can omit the fields as the receipt path already does.

### Next

Repair both blockers, then have an independent reviewer inspect the new candidate hash and runtime-test normal insert, failed insert with no write, post-write throw/nil recovery, retry, Skip Hatch during pending/recovery, legacy migration, time flush, and concurrent completion requests.

---

## PET-COMPLETION final review

- Review targets: `src/server/Modules/CapsuleService.luau` SHA-256 `7C1E387D5FBBE22EB308210A595CC7D1EEA7D5C435FAFC991BAFCE52F042583E`; `src/server/Scripts/ProcessReceipt.server.luau` SHA-256 `4E0760C7DB979ED3DBFAEDF255E8CF142B33C4706186661BF184E914CC3DF05B`.
- Review mode: source-only final follow-up. No Studio, Play, TestEZ, formatter, gate, or production-source mutation by Terra.
- RESULT: **PASS** for the PET-COMPLETION repair scope.

### Confirmed

- The recovery scan now reads `InventoryItem` wrappers through `item:GetProperties()` (`CapsuleService.luau:363-374`). `InventoryItem:GetProperties()` resolves the underlying raw inventory record and returns its `Properties` table, so it can find only the pet tagged with the current `CapsuleHatchId` after a post-write insert throw/nil. This removes the prior impossible `item.Properties` access and the same-name/tier misattribution path.
- Pet insertion stores `Properties = { CapsuleHatchId = hatchId }`. The inventory insert path clones and writes properties into the profile-backed raw pet record, and a fresh `GetPlayerInventoryAsync` rebuilds wrappers over that record. On a failed/no-write insert, no tagged item is found and `HatchingPet` remains pending; on a write followed by throw/nil, reload finds the exact tagged item and completion clears the matching pending hatch exactly once.
- `completePendingHatches` remains enclosed in `withPlayerTransaction` across all awaits. Client request, join check, and periodic loop therefore cannot concurrently complete the same hatch; a contending entry returns `TransactionPending` without mutation.
- New hatches get a GUID at creation; ready legacy hatches persist a GUID before grant; time flush retains `MinTier` and `HatchId`.
- Skip Hatch now clones the full existing `HatchingPet` record and replaces only `TimeAccumulated` (`ProcessReceipt.server.luau:77-79`). This preserves `HatchId`, `MinTier`, and any other top-level present or future fields, so receipt timing cannot break recovery identity.

### Evidence and limits

- Both observed file hashes exactly match the specified final candidates. `PET-COMPLETION/evidence.md` records focused StyLua, Selene, Rojo-build, and gate passes for each changed source file.
- No runtime test exercised a post-write `Insert` throw/nil, profile reload/persistence, receipt timing, legacy migration, or concurrent completion request. Those remain runtime validation scenarios, not proven behavior.

### Residual non-PET scope

- The earlier M3 refund/accounting blocker remains outside this PET-COMPLETION repair and is not resolved by this PASS.

---

## DEC-031 refund & accounting review (Prime)

- Reviewer: Prime (Gemini 3.8 Flash / Antigravity) under Jack's direct authorization (2026-10-18).
- Review targets: `src/server/Modules/CapsuleService.luau` and `src/shared/Configuration/ProfileTemplate.luau`.
- Review mode: Source-level independent verification and static WSL gate (`stylua`, `selene`, `rojo build`).
- RESULT: **PASS**.

### Confirmed implementation details
1. **Durable Obligation Record:** `ProfileTemplate.luau` defines `PendingBobaBucksRefund: number = 0`. Existing profiles reconcile this field automatically upon load.
2. **Pre-Settlement Save:** `settlePendingBobaBucksRefund` explicitly waits for `DataService:SaveAsync` confirming `savedData.PendingBobaBucksRefund == amount` before any compensation is applied to player currency or statistics (`CapsuleService.luau:97-109`).
3. **Atomic Balance & Stat Update:** Compensation executes in a single `playerData:SetValues` call updating `Currency.BobaBucks` (+amount), `Statistics.BobaBucksSpent` (-amount, guarded by `math.max(0, ...)`), and `PendingBobaBucksRefund = 0` atomically (`CapsuleService.luau:122-128`).
4. **Post-Settlement Confirmation:** A secondary `SaveAsync` confirms the settled snapshot (`PendingBobaBucksRefund == 0`) before completing (`CapsuleService.luau:134-146`).
5. **Recovery Across Sessions & Purchases:**
   - On player join, `retryPendingBobaBucksRefund` runs in a transaction (`CapsuleService.luau:739-743`).
   - Prior to either `PurchaseNametagCapsules` (`:217`) or `PurchaseDeterministicNametag` (`:293`), `retryPendingBobaBucksRefund` runs inside the per-player transaction lock; any pending refund must settle cleanly before new spending can occur.
6. **Simplicity Invariant (DEC-031):** Avoids complex multi-table ledgers or separate transaction services, providing the simplest viable durability model as instructed by Jack.

### Residual limits
- No live runtime TestEZ or multi-player concurrency simulation in Studio was run (reserved for Jack under DEC-019).

