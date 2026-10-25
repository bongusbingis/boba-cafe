# IMPORT-V4: Extract v4 assets to .rbxm and port dialogue lines
Model: sonnet   Studio: no (lune only)   Depends on: none   Size: M

## Goal
Package the v4 assets the revival reuses (spills, NPC looks and animations, barista uniform) as `.rbxm` files ready for one Studio insert (RIG-1), and port v4's NPC dialogue lines into a Luau data module. Settled by DEC-015 (Q24, Q25, bonus).

## Read (only these)
- `git show main:tools/extract.luau` (the lune/roblox API idioms: `roblox.deserializePlace`, `fs`, `process.args`)
- `.review/agent-workflow/tasks/REVIVAL-001/S3/evidence.md` lines 83-133 (v4 paths)
- `.review/agent-workflow/tools/wsl/env.sh` (how lune is reached)

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/IMPORT-V4/extract-v4.luau` (new; the script)
- `/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/` (outputs: `CleanlinessStorage.rbxm`, `NPCStorage-Karen.rbxm`, `NPCStorage-Animations.rbxm`, `S_DefaultUniform.rbxm`, `P_DefaultUniform.rbxm`, `CustomerConfig.v4.txt`)
- `src/shared/Configuration/CustomerDialogue.luau` (new)
- `.review/agent-workflow/tasks/REVIVAL-001/IMPORT-V4/evidence.md`

## Steps
1. `mkdir -p /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/` then `git show main:boba-v4.rbxl > /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/boba-v4.rbxl` (8.2 MB; do not commit it).
2. Write `extract-v4.luau` modelled on `tools/extract.luau`. Header: `local fs = require("@lune/fs")`, `local roblox = require("@lune/roblox")`, `local process = require("@lune/process")`. `local game = roblox.deserializePlace(fs.readFile(process.args[1]))`, `local outDir = process.args[2]`. Helper `find(root, {names})` walks `FindFirstChild` and errors with the missing path (so the evidence names exactly what is absent). Targets, each cloned with `:Clone()`:
   - `game.ReplicatedStorage.SharedStorage.CleanlinessStorage` -> `CleanlinessStorage.rbxm`
   - `game.ReplicatedStorage.SharedStorage.NPCStorage.Karen` -> `NPCStorage-Karen.rbxm`
   - `game.ReplicatedStorage.SharedStorage.NPCStorage.Animations` -> `NPCStorage-Animations.rbxm`
   - `game.ReplicatedStorage.SharedStorage.KitchenStorage.Assets.S_DefaultUniform` -> `S_DefaultUniform.rbxm`
   - `game.ReplicatedStorage.SharedStorage.KitchenStorage.Assets.P_DefaultUniform` -> `P_DefaultUniform.rbxm`
   For each clone: `clone:SetAttribute("BuiltBy", "REVIVAL-001-import-v4")`, then write `fs.writeFile(outDir .. "/" .. file, roblox.serializeModel({ clone }))`. If `serializeModel` is not accepted for a root instance in lune 0.10.5, build the same with a `Folder` parent named like the file and serialize `{ folder }`; note which form worked.
3. Same script, last part: find `game.ReplicatedStorage.Shared.Configuration.CustomerConfig` (a ModuleScript; S3 path), and write its `.Source` to `CustomerConfig.v4.txt`. If the path is absent, search all descendants for the name `CustomerConfig`; if still absent, STOP-AND-ASK.
4. Run from the repo root in WSL: `. .review/agent-workflow/tools/wsl/env.sh; lune run .review/agent-workflow/tasks/REVIVAL-001/IMPORT-V4/extract-v4.luau -- <the .rbxl path> <outDir>` (use the Windows-translated paths if the lune shim needs them; see env.sh). Then `ls -l` the outputs. Every file must be non-empty.
5. Read `CustomerConfig.v4.txt`. Write `src/shared/Configuration/CustomerDialogue.luau` as a plain-data module: `return { Default = { Greeting = {...}, WrongOrder = {...}, Leaving = {...} }, Karen = { Greeting = {...}, WrongOrder = {...}, Leaving = {...} } }` with the string lines copied verbatim from v4's pools of the same names. Skip Followup, Waiting, WorkerAction. Header comment: `-- Source: v4 CustomerConfig (DEC-015 bonus). Lines are verbatim.` Add `--!strict` only if the other Configuration modules use it (check one).
6. Verify the .rbxm round trip with a second tiny lune run: `roblox.deserializeModel(fs.readFile(file))` on each output, print root class, name, descendant count and `BuiltBy`.
7. `stylua` then `gate` on `CustomerDialogue.luau`.

## Done when
- Five `.rbxm` files and `CustomerConfig.v4.txt` exist under the output folder and each round-trips with `BuiltBy="REVIVAL-001-import-v4"` on its top-level instance.
- `CustomerDialogue.luau` passes the gate.
- The evidence lists each file with byte size, root class, descendant count.

## Checks to run
- RUNBOOK step 3 on `CustomerDialogue.luau`; the lune commands above.

## STOP-AND-ASK
- Any v4 path in step 2 is absent from `boba-v4.rbxl` (RUNBOOK: report the path searched and ask; never build a substitute, DEC-008).

## Evidence
`tasks/REVIVAL-001/IMPORT-V4/evidence.md`
