# REVIVAL-001-M0.8 - Quill documentation evidence

- Task: REVIVAL-001-M0.8. Date 2026-10-14. Role: Quill.
- Source state: branch `uhweifh`, HEAD `92f6144` plus a dirty tree (uncommitted M0 changes: ShiftService, WorldPath, ProcessReceipt, OrderService, KitchenService, and others; RankClaiming.server.luau and RankingService.luau deleted). `docs/` is untracked, so `diff.patch` is against pre-edit copies saved to `/private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m08-pre/`. Mason was editing `Recipes.luau` / OrderService / ToolNameValidityCheck in parallel; boba tool-name formats are deliberately not documented.
- Write scope: `docs/SYSTEMS.md`, `docs/ARCHITECTURE.md`, `docs/CONVENTIONS.md` only. No source edited, nothing committed, no Studio.

## Sections changed
SYSTEMS.md
- Intro: source-state sentence (2026-10-14, branch, what Studio exercised).
- Startup & Lifecycle: join kick removed (DEC-004); world-content resolution rule and known require-time exceptions; RankUtil dependency dropped.
- Player Data: `SaveAsync`, `ProcessedReceipts`.
- Currency & Statistics: `TrySpendAsync` (no callers yet), `Modify` caveat.
- Capsules: skip-hatch valid only with a pending hatch (DEC-006).
- Ordering: any player orders for self; `buildOrderItem` contract; `:expect()` + in-flight guard; clocked-in claiming/queue; bounded Ordering System wait; Studio evidence.
- Kitchen: clock-in gate instead of rank; bounded world waits; RecipeConstructors/WorldPath; KitchenController perk; Studio evidence.
- Spills: world budget and disable behavior, SpawnInterval, clocked-in cleaning; GlobalMulti gap removed.
- "Ranks, Teams & Gamepasses" split into "Shifts & Teams" (new, ShiftService) and "Ranks & Gamepasses" (RankClaiming/RankingService/ClaimRank removed).
- Purchases: durable receipts, idempotency, NotProcessedYet cases, Skip Hatch, code-created GetPurchases; old known gap removed.
- Promo Codes (code-created remote), Settings (claim-rank settings removed, audio group guard), Badges, Dialogs (consumers, Notify props), UI Shell (TopBar bounded wait).
ARCHITECTURE.md: overview, single-place model (defensive world resolution, code-created remotes), source layout (WorldPath, Scripts list), server/client boundary, data flow (shift, orders, purchases).
CONVENTIONS.md: World content rule, async/lifecycle wording, error-handling and rate-limit examples, Security (purchases, client-built data, shift not rank), testing wording, Things Not To Do.

## Claims left unverified
- ProcessReceipt behavior (idempotency, SaveAsync, Skip Hatch, unmapped product): read from source; no Studio purchase test exists. Marked unverified in SYSTEMS.md.
- `CurrencyService:TrySpendAsync` and the `ShiftService` / `CurrencyService` / `OrderService` specs: read only; TestEZ not run by this task. No caller of `TrySpendAsync` exists.
- Any two-player path (queue, second barista claim, other-player pickup, per-player ClockedIn): unverified (M0.4 run 2).
- Spills: current place logs "Spills disabled (4 authored paths missing)" per M0.4 run 2; spill behavior not run.
- `ReplicatedStorage.SharedStorage` and `Networking.InventoryEvent` described as authored content from code comments and the earlier recon; not inspected in the place.
- Known remaining require-time hazards documented, not fixed: unbounded `Menu` WaitForChild("SelectorModels") and `Inventory` WaitForChild for `InventoryEvent`.
- DEC-002 gamepass remap: documented as not implemented (nothing in code does it).
- Out of scope per brief: boba recipe/tool-name formats (Mason's parallel fix); `Ordering/PlayerSelectPage.luau` dead-code note from review not documented.
