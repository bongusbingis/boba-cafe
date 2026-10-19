  - Failed-grant compensation is recorded in a single additive pending-refund amount, saved before it is issued, and retried on join and before another capsule spend.
  - When compensation is issued, restore BobaBucks and reduce BobaBucksSpent in the same profile update; clear the pending amount in that update.
# M3-BULK-NAMETAG: safe Nametag capsule stacks and BobaBucks purchase
Model: Prime/Mason   Studio: no   Depends on: DEC-029 E10 + E16 approved scope   Size: M

## Goal
Implement the approved E10 Nametag capsule catalog and BobaBucks purchase path safely. A single capsule costs 150 BB, a 10-pack costs 1,350 BB, and a 50-pack costs 6,000 BB. Ensure policy restricted players cannot purchase or hatch paid-random capsules; preserve the free first-shift capsule.

## Read
- `.review/agent-workflow/decisions.md` DEC-029, DEC-028, DEC-024
- `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/evidence.md` Terra E10/E16 findings
- `docs/AI_AGENT_WORKFLOW.md`, `docs/STYLE.md`
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau` capsule catalog and odds source definitions
- `src/shared/Configuration/InventoryItemDefinitions/Capsules.luau`
- `src/shared/Configuration/InventoryItemDefinitions/Tiers.luau`
- `src/shared/Inventory/{InventoryServer,InventoryItem,ItemActions,Utility}.luau`
- `src/server/Modules/{CapsuleService,CurrencyService}.luau`
- `src/shared/Configuration/ProfileTemplate.luau` for the additive pending-refund field
- `src/shared/UI/Pages/Shop/{init,RandomCosmeticsPurchase}.luau`
- `src/shared/UI/Pages/Inventory/InventoryComponent.luau`

## Write scope
- `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau`
- `src/shared/Inventory/InventoryServer.luau`
- `src/shared/Inventory/InventoryItem.luau`
- `src/shared/Inventory/ItemActions.luau`
- `src/server/Modules/CapsuleService.luau`
- `src/shared/Configuration/ProfileTemplate.luau` (additive `PendingBobaBucksRefund` default/type only)
- `src/server/Modules/CurrencyService.luau` (only if a minimal, auditable refund fix requires it; preserve pre-existing changes)
- `src/shared/UI/Pages/Shop/init.luau`
- `src/shared/UI/Pages/Shop/RandomCosmeticsPurchase.luau`
- `src/shared/UI/Pages/Shop/DirectCosmeticsPurchase.luau` (approved restricted-user deterministic Nametag alternative)
- `src/shared/UI/Pages/Inventory/InventoryComponent.luau`
- `.review/agent-workflow/tasks/REVIVAL-001/M3-BULK-NAMETAG/evidence.md`

## Invariants
- Server determines pack SKU, price, quantity, policy eligibility, affordability, and reward. Never trust client-supplied amount/price/reward.
- Restricted users cannot purchase or open paid-random items, including with BobaBucks; policy lookup failure fails closed for paid actions.
- Mark purchased capsules `Properties.RandomSource = "Paid"`; mark the existing free first-shift capsule `FreeEarned`. Restricted users may hatch only explicitly `FreeEarned`; missing/legacy source fails closed without consuming the item.
- A pack occupies one capsule inventory record with `StackCount`; never insert 50 separate records. Respect capacity and avoid charging if the grant cannot be completed. A failed reward insertion must leave the capsule count intact.
- Preserve all existing player changes and existing single-capsule price. Do not add direct Robux product IDs, receipts, Creator Hub changes, or new pet product scope.
- Show the full possible Nametag outcome list and actual numeric per-item odds before an eligible player can purchase. Use existing UI components/tokens/patterns; no new style tokens or unrelated redesign.

## Acceptance
- Failed-grant refunds remain recoverable across reconnects through one aggregate saved obligation; no new refund ledger or transaction service.
- Compensation changes BobaBucks and BobaBucksSpent together and clears the obligation; new capsule spends wait for pending compensation to settle.
- Server recognizes only approved 1/10/50 pack choices and applies 150/1,350/6,000 BB respectively.
- Purchase path checks policy and inventory capacity before currency is deducted; invalid SKU, insufficient funds, restricted status, failed policy lookup, or full inventory produce no charge and no capsule change.
- Successful purchases add to an existing Nametag capsule stack when present; otherwise insert one stack record. Client UI shows total stack count including StackCount values.
- Opening one Nametag capsule consumes exactly one from the stack only after a reward is successfully inserted. If reward insertion fails, the capsule remains.
- Free first-shift capsule remains grantable and openable for restricted users. Paid or source-unknown capsules cannot be opened by restricted users.
- Nametag page includes actual per-outcome odds before purchase; restricted users see no paid-random purchase action.
- No direct Robux capsule SKUs are added in this task; receipt fallback/product IDs remain separate E16 blockers.

## Checks
- From repository root: `scripts/gate.sh <each changed .luau file>` (no extra tests per RUNBOOK).
- Studio: no. Jack's later batched runtime/TestEZ verification remains required by the global code gate; do not claim runtime pass.

## Stop and ask
Stop if the full outcome odds cannot be derived from current definitions or if safe receipt/source handling requires an unapproved reward or schema migration.

## Forbidden
- Changing any approved price, odds, reward, Creator Hub setting, or product ID.
- Implementing direct Robux purchase/receipt paths or E18/E22 behavior.
- Running Studio/Play/TestEZ, editing unrelated files, committing, or publishing.
