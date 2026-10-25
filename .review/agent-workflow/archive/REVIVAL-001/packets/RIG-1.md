# RIG-1: Studio rigging pass (imports, NPC world contract, interior spawns, spills, trash audit)
Model: sonnet   Studio: yes   Depends on: IMPORT-V4   Size: L (one Studio pass, DEC-012)

## Goal
The dev place contains everything the code expects: the imported v4 content in the paths SPILLS and NPC-LOOK read, the NPC route and counter, spawns inside the cafe, and spill areas. Settled by DEC-015 (Q7, Q8, Q9, Q24, Q25), DEC-012 (computer use allowed, one pass), DEC-008.

## Read (only these)
- `tasks/REVIVAL-001/IMPORT-V4/evidence.md` (the file list)
- `M1.2/design.md` line 458 (the M1.4a row, the contract) and `tasks/REVIVAL-001/M1.4core/evidence.md` lines 40-60 (contract rules: Entry/Exit BaseParts; Path/Queue/Counter hold BaseParts named by number; Counter parts face the kitchen)
- `tasks/REVIVAL-001/S3/evidence.md` lines 83-133 (v4 spill areas, trash cans)
- `tasks/REVIVAL-001/S1/evidence.md`: grep only for `OldScriptables`, `SpawnLocation`, `Spills`, `TrashCan`, `Clear Cup`
- `src/server/Modules/SpillService/init.luau` lines 55-80 (what the service resolves)

## Write scope
- The "jacks project" place (Studio), only the instances listed below
- `tasks/REVIVAL-001/RIG-1/evidence.md` and `tasks/REVIVAL-001/RIG-1/*.png`

## Steps
1. In Studio Edit mode, File > Insert from File for each of these, from `C:\Users\jackc\AppData\Local\Temp\boba-gate\v4-import\`, then move the result to the path shown (create the folder with `BuiltBy="RIG-1"` if absent; never delete anything):
   - `CleanlinessStorage.rbxm` -> `ReplicatedStorage.SharedStorage.CleanlinessStorage`
   - `NPCStorage-Karen.rbxm` -> `ReplicatedStorage.SharedStorage.NPCStorage.Karen`
   - `NPCStorage-Animations.rbxm` -> `ReplicatedStorage.SharedStorage.NPCStorage.Animations`
   - `NPCStorage-Idle.rbxm` -> into `ReplicatedStorage.SharedStorage.NPCStorage.Animations` (as a child named `Idle`)
   - `S_DefaultUniform.rbxm` and `P_DefaultUniform.rbxm` -> `ReplicatedStorage.SharedStorage.KitchenStorage.Assets.S_DefaultUniform` / `.P_DefaultUniform`
   Confirm each top-level instance still has `BuiltBy="REVIVAL-001-import-v4"`. Print the child names of each into the evidence. If `CleanlinessStorage` lacks `Spills.Boba`, `Tools.Mop`, `Tools.MopBucket` or `Sparkles`, record RESULT: BLOCKED.
2. **Interior spawns (Q7).** Find the existing `SpawnLocation`s (record each path and position). Set `Enabled = false` on each old outside spawn (do not delete). Add 4 new `SpawnLocation`s named `SpawnInterior1..4` under `workspace.Map.SpawnLocations` (or the folder that holds the old ones), `BuiltBy="RIG-1"`, `Neutral = true`, Duration 0, placed inside the cafe in a line within 30 studs walking distance of the `Clear Cup` station Model (`workspace.Assets.Kitchen`, name `Clear Cup`). Measure each with `PathfindingService:ComputeAsync` (length 30 or less) and put the numbers in the evidence.
3. **NPC world contract (Q8, M1.4a row).** Create `workspace.Assets.NPC` (Folder, `BuiltBy="RIG-1"`) holding: `Entry` (Part, at the front door), `Exit` (Part, beside Entry), `Path` (Folder of Parts `1..n` leading from Entry to the queue), `Queue` (Folder of Parts `1..k`, front first, k = 6), `Counter` (Folder of Parts `1..m`, m = 5, beside the kitchen, each Part's LookVector facing the kitchen, each 25 studs or less walking from the Tapioca wells and the Coffee Machine). Every Part: Anchored true, CanCollide false, CanQuery false, CanTouch false, Transparency 1, size 2x1x2. Clone `workspace.OldScriptables.NPCFolder` nodes (Spawn, Traversable, OrderPickup) where their positions fit and rename the clones to the numbered names; otherwise place new Parts. Record every Part's name and Position in the evidence. Place Exit so that a straight walk from every Counter part to Exit is clear of walls (the NPC walks straight from its counter spot to Exit; M1.4core question 2); step 6 verifies it.
4. **Spill areas (Q24).** Under `workspace.Assets.Spills` make sure `Areas` (Folder) holds at least 8 Parts covering the open floor of the cafe seating and queue (Anchored, CanCollide false, Transparency 1, `BuiltBy="RIG-1"`); keep existing Parts. Also make sure `Boards` and `Active` exist (Folders).
5. **Trash cans (Q9).** List the paths of the 6 trash can Models in the dev place (search names containing `trash` or `bin`, case-insensitive, under `workspace`). Put the exact paths and each can's PrimaryPart name in the evidence under the heading `## Trash can paths`. Do not change them.
6. **Check.** Run in the command bar: for `Counter` part 1..m, a `Humanoid:MoveTo` walk test is not possible in Edit mode; instead run `PathfindingService:ComputeAsync(Entry.Position, Counter[i].Position)` and `(Counter[i].Position, Exit.Position)` for each i; record Success/length. Then press Play once and read the Output: expect no errors and `CustomerService`/`SpillService` messages, nothing else. Stop.
7. **Capture.** One Studio screenshot of the spawn and the counter, saved to `tasks/REVIVAL-001/RIG-1/capture-spawn-counter.png`.
8. File > Save to Roblox (DEC-012). Never publish.

## Done when
- Every path in step 1 exists with `BuiltBy`; the evidence lists child names.
- Contract parts in step 3 exist, with the property set confirmed by a printed check.
- All path computations in steps 2 and 6 succeeded and are tabulated.
- Six trash can paths are recorded; the capture exists; the place is saved.

## Checks to run
- The Studio steps above; no gate (no repo code changes).

## Extra step (Prime, 2026-10-17)
- Add the CollectionService tag `TrashCan` to each of the 6 trash can Models (Tag Editor or `CollectionService:AddTag`). TrashService wires tagged cans.

## STOP-AND-ASK
- Any `.rbxm` is missing from the import folder (run IMPORT-V4 first).
- Fewer than 6 trash cans are found: report the names searched.
- A walking distance in step 2 or 3 cannot be met inside the building: report the numbers and ask.

## Evidence
`tasks/REVIVAL-001/RIG-1/evidence.md`
