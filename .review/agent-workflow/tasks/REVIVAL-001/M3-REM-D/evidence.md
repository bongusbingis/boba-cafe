# M3-REM-D evidence: Double Storage (InventoryX2)

Decisions: DEC-042 Q-D1=A (x2 Storage only, Equipped unchanged), Q-D2=A (nothing deleted on pass loss; only new additions blocked while over the limit).

## Changed files
- src/shared/Configuration/Perks.luau (StorageMultiplier = 2)
- src/server/Modules/PerkService.luau (_storageMultiplier cache, RefreshStorageMultiplier, GetStorageMultiplier, PlayerAdded chain, PlayerRemoving clear)
- src/shared/Inventory/Utility.luau (optional storageMultiplier arg; Storage only, ignored if non-number or < 1)
- src/shared/Inventory/InventoryServer.luau (Insert only; sync pcall read)
- src/server/Modules/CapsuleService.luau (storageLimit helper; five sites; InventoryLimits requires removed, unused)
- src/server/Tests/PerkService.spec.luau (new cases), src/server/Tests/InventoryLimit.spec.luau (new)

## Serve-path / atomicity
No yielding call added. GetStorageMultiplier is a table read; the limit is resolved before each count and no yield sits between count and Insert. CustomerService and RealOrderService untouched. No require cycle (PerkService required lazily inside pcall at Insert time).

## Gate
GATE: PASS on all 7 files (selene new=0, stylua ok, rojo build ok). TestEZ/Play not run.

## Test for Jack
Temporarily set BASE_STORAGE in InventoryLimits.luau to 3, revert after. Account needs pass 14067346 for owner cases (rejoin after buying).
1. No pass: buy nametag capsules to 3; next purchase refused (InventoryFull), no BobaBucks spent. Same for nametags and a pet hatch (stays pending).
2. With pass: same actions succeed to 6, then refuse.
3. Daily reward / chest capsule at 3 (no pass) refuses; at 4 (pass) succeeds.
4. Equipped limits unchanged: 1 pet, 1 nametag, 5 particles.
5. Over-limit (pass lost, Q-D2=A): nothing deleted/hidden, items usable and sellable, only new additions refused until under limit.
6. Claim in the first second after joining: at worst refused, never over-granted; retry works.
7. Pass bought mid-session applies after rejoin (as every pass perk).
