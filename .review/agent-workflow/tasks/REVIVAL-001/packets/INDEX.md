> **Status 2026-10-16:** R1-FIX is DONE. M1.5b was stopped mid-run (check OrderTicket.luau/RecipeCard.luau for partial edits). M1.6 is Jack's playtest (DEC-019), not an agent lane.

# REVIVAL-001 packet index (M1 remainder)

Status is "ready" or "waiting on X". R1-FIX is being written/run elsewhere; M1.5b is already written. Packets that write the same file must not run together (see Conflicts).

| ID | Depends on | Model | Studio | Status |
|---|---|---|---|---|
| R1-FIX | none | sonnet | no | in progress (outside this index) |
| M1.5b | none (UI-CONV, M1.5a, M1.5cd done) | sonnet | no | ready |
| IMPORT-V4 | none | sonnet | no (lune) | ready |
| SPILLS | none (runtime check later) | sonnet | no | ready |
| Q14-GATES | R1-FIX | sonnet | no | waiting on R1-FIX |
| M1.4e | R1-FIX | sonnet | no | waiting on R1-FIX |
| RIG-1 | IMPORT-V4 | sonnet | yes | waiting on IMPORT-V4 |
| TRASH | RIG-1 (can paths) | sonnet | no | waiting on RIG-1 |
| M1.4f | M1.4e, M1.5b | sonnet | no | waiting on M1.4e, M1.5b |
| NPC-LOOK | M1.4e, IMPORT-V4, RIG-1 | sonnet | no | waiting on M1.4e, RIG-1 |
| M1.MEASURE | M1.4e, NPC-LOOK | sonnet | no | waiting on NPC-LOOK |
| Q-DOCS-M1 | RIG-1, M1.4f, TRASH, NPC-LOOK, SPILLS, Q14-GATES | haiku | no | waiting on all of those |
| M1.6 | everything above | sonnet | yes | waiting on all |

## Recommended waves
1. In parallel: R1-FIX, M1.5b, IMPORT-V4, SPILLS.
2. When R1-FIX is done: Q14-GATES and M1.4e in parallel. Also RIG-1 (Studio, one lane) when IMPORT-V4 is done.
3. When M1.4e and M1.5b are done: M1.4f. When RIG-1 is done: TRASH. When M1.4e and RIG-1 are done: NPC-LOOK.
4. M1.MEASURE after NPC-LOOK.
5. Q-DOCS-M1, then M1.6 (the single Studio verification pass).

## Conflicts (never run together)
- R1-FIX vs M1.4e vs NPC-LOOK vs M1.MEASURE: all edit `src/server/Modules/CustomerService/init.luau` (and `Npc.luau` for the first three). Run in that order.
- R1-FIX vs Q14-GATES: both edit `src/shared/Kitchen/Recipes.luau` and `RecipeConstructors.luau`. R1-FIX first.
- M1.5b vs M1.4f: both edit `src/shared/UI/Components/Core/Hud/OrderTicket.luau`. M1.5b first.
- Q14-GATES vs M1.5b: Q14 edits `OrderSpec.luau` (`StepState`); M1.5b only reads it. No conflict if M1.5b does not edit OrderSpec.
- M1.MEASURE vs M1.4e: both touch `CurrencyService.luau`/`CustomerService/init.luau`; M1.4e first.
- RIG-1 and M1.6 each hold the Studio lease; never together, never with another Studio lane.

## M3 follow-up

| ID | Depends on | Model | Studio | Status |
|---|---|---|---|---|
| M3-BULK-NAMETAG | DEC-029 E10 and E16 policy approval | prime/mason | no | ready (Prime lease active) |

