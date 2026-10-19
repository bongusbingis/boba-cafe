# M3-STARTER-CAPSULE

status: ready
role: mason (Prime combines implementation for this small scoped change)
model: Muse Spark lane

## Objective

Grant one free Regular Pet Capsule through the inventory API after a player's first completed shift, without blocking shift completion or play if the grant cannot be made.

## Basis

- `.review/agent-workflow/decisions.md`, DEC-023 E24 confirmed by DEC-024: server-side, one-time, end of first shift, through inventory API; grant failure must not block shift completion or play.
- Jack selected marker-first (B) and asked for the most practical failure handling.
- Terra review: the capsule definition is valid; the production Capsules storage limit is 10; `Insert` returns nil for invalid data or full inventory; profile `SetValue` mutates the active in-memory profile and persistence occurs later. No atomic cross-write API was found.

## Read scope

- `src/server/Modules/CapsuleService.luau`
- `src/server/Modules/ShiftService.luau`
- `src/shared/Inventory/InventoryServer.luau`
- `src/shared/Inventory/Utility.luau`
- `src/shared/Configuration/InventoryLimits.luau`
- `src/shared/Configuration/InventoryItemDefinitions/Capsules.luau`
- `.review/agent-workflow/decisions.md`
- `.review/agent-workflow/tasks/REVIVAL-001/M3-E24-REVIEW/evidence.md`

## Write scope

- `src/server/Modules/CapsuleService.luau`
- `.review/agent-workflow/tasks/REVIVAL-001/M3-STARTER-CAPSULE/`
- `.review/agent-workflow/board.json`
- `.review/agent-workflow/completed.ndjson`

## Invariants

- Do not alter the approved reward, timing, or once-per-player intent.
- Do not block shift completion or player play on reward failure.
- Do not bypass the inventory API or exceed its storage limit.
- Keep the marker and item write server-side; preserve existing player data.
- Never claim crash-atomic persistence; the repository has no inspected primitive for it.

## Acceptance

- Only `summary.First` schedules the grant.
- Existing `Inventory.FreeItemsRedeemed` marker prevents a second grant.
- A full inventory does not set the marker; a nil Insert result rolls the marker back.
- Failures are logged and isolated from shift completion.
- No Studio Play/TestEZ is run by the agent (DEC-019).

## Checks

- WSL `stylua` and `gate` for the changed Luau file, following `RUNBOOK.md`.
- Review final diff and parse updated board/ledger.

## Forbidden

- Changes to reward amount/type/timing, inventory limits, profile schema, or unrelated capsule behavior.
- Studio Play/TestEZ, data migration, or changes to unresolved M3 decisions.

## Source snapshot

- Repository HEAD at recovery: `cbf5271`.
- Working tree already contained unrelated pre-existing edits; preserve them.
- Terra evidence: `.review/agent-workflow/tasks/REVIVAL-001/M3-E24-REVIEW/evidence.md`.
