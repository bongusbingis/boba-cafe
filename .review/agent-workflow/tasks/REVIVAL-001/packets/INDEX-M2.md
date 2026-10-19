# M2 packet index
Run in this order. Packets in the same row can run in parallel because their write scopes do not overlap.

| Wave | Packets | Why this order |
|---|---|---|
| 1 | M2-SHIFT | First. Adds `CustomerResolved` and `ShiftEnding` signals, `ShiftsCompleted` stat, mounts a Hud card. Needs M1.4e and M1.5b done. |
| 2 | M2-PROGRESS | Needs the signals. Adds `Level`/`XP` to ProfileTemplate, level-aware `Rules.PickOrder`, ticket slots. |
| 3 | M2-VARIANTS, M2-REALORDER, M2-AREAS (Studio, Rigger), M2-RECIPEBOOK | Disjoint write scopes after waves 1-2 (see below). |
| 4 | M2-RATING | Last of the CustomerService editors: edits the pay path after VARIANTS and `Hud/init.luau` after SHIFT. |

## File conflicts (never run these at the same time)
- `src/server/Modules/CustomerService/init.luau`: SHIFT, PROGRESS, VARIANTS, RATING. Order: SHIFT, PROGRESS, VARIANTS, RATING.
- `src/server/Modules/CustomerService/Rules.luau`, `src/shared/Configuration/CustomerConfig.luau`: PROGRESS, VARIANTS. Order: PROGRESS then VARIANTS. (RATING and REALORDER put constants in their own new Config files to avoid this.)
- `src/server/Modules/CustomerService/Npc.luau`, `src/server/Tests/CustomerService.spec.luau`: VARIANTS only.
- `src/shared/Configuration/ProfileTemplate.luau`: SHIFT (ShiftsCompleted), PROGRESS (Level, XP), REALORDER (RegularOrders). Order: SHIFT, PROGRESS, REALORDER; REALORDER must not overlap in time with the other two.
- `src/shared/UI/Components/Core/Hud/init.luau`: SHIFT, RATING. SHIFT first.
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau`: SHIFT, RECIPEBOOK. SHIFT first.
- `src/server/Modules/OrderService.luau`: REALORDER only.
- `src/server/Modules/SpillService/init.luau`: RATING only.
- `src/server/Modules/ShiftService.luau`: SHIFT only.

## Dependencies on earlier milestones
M1.4e, M1.4f, M1.5b must be done (ticket contract, OrderTicket, CustomerService). M2-AREAS needs `Level` from PROGRESS.

## Design gaps found (each is a STOP-AND-ASK in its packet)
- PROGRESS: HUD for a 2nd ticket; nametag catalog size for L35-L50; no title system; no spill XP value.
- VARIANTS: Karen description location in the dev place; "angry emote"; NPC seating rule (design only says "seating is M2"); VIP spawn chance.
- RATING: free top-centre HUD spot; fast-serve rating delta absent in design; Rush Hour banner/music/lighting assets. The SpillService 100% crash named in the plan is already gone (SYSTEMS.md); no fix needed.
- REALORDER: hearts rating and ready beam out of scope; base pay for player orders.
- AREAS: desert line approval; design says no server check for break areas (the packet request mentioned one).
- RECIPEBOOK: step label field; Tips copy; old Staff Points text.
- SHIFT: HUD zone for the card; shift bonus/tip values are 0 placeholders until M3.
- M2-TRASH-FOLLOWUP: skipped as instructed.
