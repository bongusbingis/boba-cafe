# SPILLS: Point SpillService at CleanlinessStorage
Model: sonnet   Studio: no   Depends on: none for code (runtime check needs RIG-1)   Size: S

## Goal
Spills spawn and can be cleaned, using the v4 content imported to `ReplicatedStorage.SharedStorage.CleanlinessStorage`. Settled by DEC-015 Q24. Cafe Rating and Rush Hour are M2 and NOT in this packet.

## Read (only these)
- `src/server/Modules/SpillService/init.luau` lines 28-130
- `src/server/Modules/SpillService/Spill.luau`: grep `Storage\|SharedStorage\|Sparkles\|Tools\|Animations` and read 10 lines around each hit
- `tasks/REVIVAL-001/S3/evidence.md` lines 83-133, the Q24 row only

## Write scope
- `src/server/Modules/SpillService/init.luau`
- `src/server/Modules/SpillService/Spill.luau` (only if it holds a storage path)
- `src/server/Tests/` spec only if one already names the old path (grep `SharedStorage.*Spills` in `src/server/Tests`)

## Steps
1. In `init.luau` (lines ~66-77), change `WorldPath.waitFor(ReplicatedStorage, { "SharedStorage", "Spills" }, ...)` to `{ "SharedStorage", "CleanlinessStorage" }`. Keep the four required child paths: `{ "Spills", "Boba" }`, `{ "Tools", "Mop" }`, `{ "Tools", "MopBucket" }`, `{ "Sparkles" }` (v4 has all four under CleanlinessStorage, S3 Q24). Update the missing-content strings and the field comment on line ~35 to say `CleanlinessStorage`.
2. `grep -rn '"Spills"' src` and `grep -rn "SharedStorage.Spills" src docs`; change any other code reference to the storage folder (not `workspace.Assets.Spills`, which stays). List docs hits in the evidence for Q-DOCS-M1; do not edit docs here.
3. `stylua` then `gate` on changed files.

## Done when
- The gate passes (RUNBOOK step 3).
- `grep -rn "SharedStorage.*\"Spills\"" src` returns nothing for the storage path.
- Runtime (spill appears, mop cleans it) is UNVERIFIED for M1.6.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN.

## STOP-AND-ASK
- `Spill.luau` uses a child name that v4's `CleanlinessStorage` lacks (S3 lists Spills/{Boba, MeltedPopsicle, Donut}, Tools/{Mop, MopBucket, Broom, DishTowel, SprayBottle}, Sparkles, Animations): name it and ask.

## Evidence
`tasks/REVIVAL-001/SPILLS/evidence.md` (add Gauge steps for M1.6: wait for a spill, clean it with the mop, SpillsCleaned stat goes up).
