# M3-EPIC-PRICE: Set approved Epic capsule price
Model: Prime/Luna (combined Mason)   Studio: no   Depends on: DEC-024   Size: S

## Goal
Set the Epic Pet Capsule's approved price in both inventory definition mirrors.

## Read (only these)
- `.review/agent-workflow/decisions.md:5-19` - DEC-024 approval and exact price.
- `src/shared/Configuration/InventoryItemDefinitions/Capsules.luau:34-40` - canonical capsule definition.
- `src/shared/Configuration/InventoryItemDefinitions/Pets.luau:171-179` - shop mirror.

## Write scope
- `src/shared/Configuration/InventoryItemDefinitions/Capsules.luau`
- `src/shared/Configuration/InventoryItemDefinitions/Pets.luau`

## Steps
1. Set `Epic Pet Capsule` `Price` to `" 1200"` in both files, per DEC-023 as confirmed by DEC-024.
2. Make no other economy or catalog changes.

## Done when
- Both Epic Pet Capsule price mirrors equal `" 1200"`.
- No other price field changed.

## Checks to run
- From WSL repo root: `. .review/agent-workflow/tools/wsl/env.sh`, then `stylua` and `gate` on the two write-scope files.

## STOP-AND-ASK
- None for the approved value. Stop if the expected entry or mirror differs from the read scope.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/M3-EPIC-PRICE/evidence.md`
