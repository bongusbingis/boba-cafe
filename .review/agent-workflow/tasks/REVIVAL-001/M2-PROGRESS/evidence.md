RESULT: PASS (server-only; Studio NOT RUN)
Changed: src/shared/Configuration/Progression.luau (new), src/server/Modules/ProgressionService.luau (new), ProfileTemplate.luau (Level=1, XP=0), CustomerConfig.luau (MinLevel on pool, ITEM_COUNT_BY_LEVEL), CustomerService/Rules.luau (PickOrder(rng, config, level), ItemCountForLevel), CustomerService/init.luau (level pick, slot list, Items=1), src/server/Tests/Progression.spec.luau (new).
Gate: PASS on all 7 files, no new findings.

SHAPES FOR NEXT LANE (M2-TICKET2):
- Server `_tickets[player] = { [slot:number] = ticket }`, slots <= Progression.SlotsFor(level) (1; 2 from L5).
- TicketChanged:Fire(player, ticket, slot): the ticket is the old M1.4f table plus `Slot = n`; a clear is `(player, nil, slot)`. The 3rd arg is the slot. The existing client handler (OrderController.luau:79) takes only `ticket`, so at L5+ the 2nd ticket currently overwrites the 1st on the client until TICKET2 changes it.
- Player attributes: `Level` (number, set on join after profile loads and on level-up), `LevelTitle` (string, from Progression.TitleFor(level): Trainee L1, Barista 5, Senior Barista 10, Head Barista 15, Boba Expert 20, Boba Specialist 25, Boba Master 30, Boba Maestro 35, Boba Champion 40, Boba Hero 45, Boba Legend 50). Names PROPOSED (Jack).
- CustomerResolved result gains `Items` (1). ShiftEnding summary gets Xp, LevelBefore, LevelAfter (LevelAfter predicted from cache; the XP write lands when the profile promise resolves).

Notes: ORDER_POOL still has only the 3 M1 items (MinLevel 1); MIN_LEVEL_BY_ITEM in Progression is the table for later pool entries. Multi-item NPC orders (2 at L5, 3 at L15) are only a Rules function; Npc holds one order, so wiring them is a separate change. Rewards use the first 10 Nametags in file order (20 exist).
Studio for Jack: serve 5 customers, see XP/Level attributes and the level-up toast; L5 nametag in inventory.
Questions: Spill-cleaning XP value (none awarded yet); title names; multi-item Npc support lane?
