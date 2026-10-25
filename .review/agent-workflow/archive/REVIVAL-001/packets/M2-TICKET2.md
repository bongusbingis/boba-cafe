# M2-TICKET2: Client second ticket stack + level title on overhead
Model: sonnet   Studio: no   Depends on: M2-PROGRESS   Size: S

## Goal
At level 5 and above, a player can hold 2 NPC tickets, and both show on screen. The player's level title shows on their overhead (DEC-021).

## Read (only these)
- `tasks/REVIVAL-001/M2-PROGRESS/evidence.md` (the ticket list shape and the `LevelTitle` attribute)
- `src/client/Modules/OrderController.luau`: grep `TicketChanged`
- `src/shared/UI/Components/Core/Hud/OrderTicket.luau` and `Hud/init.luau` (the mount)
- `src/client/Scripts/PlayerOverheads.client.luau`
- `docs/STYLE.md` §6.6

## Write scope
- `src/client/Modules/OrderController.luau`
- `src/shared/UI/Components/Core/Hud/OrderTicket.luau` and `Hud/init.luau`
- `src/client/Scripts/PlayerOverheads.client.luau`

## Steps
1. OrderController keeps a list of up to 2 NPC tickets, keyed by ticket Id, built from the `TicketChanged` events in the shape given in the M2-PROGRESS evidence.
2. The Hud mounts one OrderTicket per ticket, stacked vertically under the first, with the same spacing as the existing HUD stacks (STYLE §2.4). The first ticket keeps its RecipeCard; the second shows its label and patience.
3. The overhead adds a line with the `LevelTitle` attribute under the name. Copy the existing overhead text label exactly (same font, size and colour as the rank line). Update it on AttributeChanged.

## Done when
The gate passes.

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M2-TICKET2/evidence.md` (5 lines)
