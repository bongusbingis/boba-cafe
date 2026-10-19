# M2-AREAS evidence (code only)
- Added `src/client/Modules/AreaController.luau`: waits 10 s for `ReplicatedStorage.AreaLimits.BreakGates`; if missing, warns once and does nothing (never blocks/kicks).
- `refresh()`: Level (default 1) < OPEN_LEVEL (3) clones every gate except `Gate_Template` into `workspace.AreaLimitsLocal` once; otherwise destroys that folder. Re-runs on `Level` attribute change.
- Gate: selene new=0, stylua ok, rojo build ok, GATE: PASS.
- Gates and desert walls are placed by Jack in Studio (Prime created `BreakGates` with parked `Gate_Template` and `workspace.Assets.AreaLimits.DesertWalls`). No server check per design 8. No Studio, no Play-test.

## Test for Jack
Join on a fresh profile (Level 1), walk to a break-area gate: blocked with the sign. Reach Level 3: gates vanish without rejoining.
