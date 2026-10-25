# BIG-B4 (Living Cafe Seating System) — evidence

Implemented according to Jack's approved design decisions:
- 80% chance (`SIT_CHANCE = 0.8`), 80-stud search radius from counter (`SEAT_MAX_DISTANCE_STUDS = 80`), 8 seat budget (`SEATED_BUDGET = 8`).
- Standard Roblox `Seat:Sit(humanoid)` without custom animation tracks per Jack's instruction.
- Reusing existing drink tool: when served, the tool is cloned onto `npc.Model` so the NPC carries their drink to the table and holds it while seated.
- Pacing subtraction: seated NPCs do not block waiting register spawns (`self._npcCount - self._seats:BudgetUsed() >= self:_pacingTarget()`).
- Feature flag: runs when `SeatingConfig.ENABLED == true` or via Studio override `workspace:GetAttribute("B4SeatingForce") == true`.

## Files changed:
- `src/server/Modules/CustomerService/Seats.luau` (new)
- `src/server/Modules/CustomerService/init.luau` (wired pool, pacing subtraction, tool cloning)
- `src/server/Modules/CustomerService/Npc.luau` (wired `_run` tail seat phase, sitting, release)
- `src/server/Tests/Seats.spec.luau` (11 unit tests)

## Gates:
- `stylua --check`: Clean (0 diffs).
- `selene`: Clean (0 errors, 0 warnings).
- `rojo build default.project.json`: Success.
- Studio TestEZ run: `Seats.spec` (11 passed, 0 failed), `CustomerService.spec` (104 passed, 0 failed).
