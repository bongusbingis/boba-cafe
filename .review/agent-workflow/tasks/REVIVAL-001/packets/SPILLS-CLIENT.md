# SPILLS-CLIENT: Client spills use CleanlinessStorage; menus hide off-launch items
Model: sonnet   Studio: no   Depends on: SPILLS, R1-FIX (done)   Size: S

## Goal
1. The client spill code finds the assets where the server now looks (`ReplicatedStorage.SharedStorage.CleanlinessStorage`, DEC-015 Q24).
2. Players only see orderable items: the menus hide anything the server would refuse (`Menu.IsLaunchItem`, from R1-FIX).

## Read (only these)
- `tasks/REVIVAL-001/SPILLS/evidence.md` and `tasks/REVIVAL-001/IMPORT-V4/evidence.md`
- `src/client/Modules/SpillController.lua`: lines 100-120, 190-210, 250-265 (grep `SharedStorage.Spills`)
- `src/server/Modules/SpillService/init.luau`: grep `CleanlinessStorage` (the path the server uses)
- `src/shared/Ordering/Menu.luau`: grep `IsLaunchItem`, `LaunchItems`, `LaunchChoices`
- Menu-listing UI: `grep -rln "Ordering.Menu\|require.*Menu" src/shared/UI/Pages` (open only the files that build item lists, by line range)

## Write scope
- `src/client/Modules/SpillController.lua`
- The UI page files under `src/shared/UI/Pages/{MobileOrder,Ordering,Menu}/` that list items (name them in the note)

## Steps
1. Repoint every `SharedStorage.Spills` reference in SpillController to `SharedStorage.CleanlinessStorage`, matching the child names the server uses.
2. Check that each child the client reads (for example `Animations`, `BoardInterface`) exists in the v4 import. List the children of `/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/CleanlinessStorage.rbxm` with lune (`roblox.deserializeModel`).
   - If a needed child is missing, keep the old path for that child only, and add a STOP-AND-ASK line to your note.
3. In each page that lists menu items or choices, skip any item where `Menu.IsLaunchItem(...)` is false, and any choice not in `LaunchChoices`. Use the helper's real signature (grep it). Change only the filtering; the visuals stay as they are.

## Done when
- The gate passes (warnings OK).
- No `SharedStorage.Spills` remains, except entries logged under STOP-AND-ASK.

## STOP-AND-ASK
- A child the client needs is missing from CleanlinessStorage.

## Evidence
`tasks/REVIVAL-001/SPILLS-CLIENT/evidence.md` (5 lines, RUNBOOK step 5)
