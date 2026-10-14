RESULT: PASS

# REVIVAL-001-M0.11: use Jack's SyrupDispenser (Rigger lease, Studio 0bec4a01-246f-4fcf-b1b5-d37cfaf45e80, unsaved)

## Jack's original (exactly one candidate; unmodified)
- Path: `ReplicatedFirst.sssArchive.Services.KitchenService.Assets.SyrupDispenser` (Model). Jack's shorthand omitted the `Assets` level and the service is ReplicatedFirst, not ServerScriptService.
- Exhaustive name search (dispenser / syrup / sssarchive, whole DataModel) found no other original. The only other match is the agent-built one below.
- Children (all MeshPart): `Liquid` (0.65x1.25x0.65, white SmoothPlastic), `Bottle` (PrimaryPart), `Pump` (0.76x2.17x0.25), `Rim` (0.27x0.05x0.27, white SmoothPlastic). No attributes, no scripts.
- Roles: Liquid and Rim exist under those exact names, so no part had to be mapped.
- Pivot = Bottle CFrame, yaw 15 deg, the same yaw as `workspace.Assets.Kitchen.Syrups.SyrupsArea`. Pump offset in the model's local space is about -Z, so the spout faces -Z, which matches the old contract.

## Code contract (no code change)
`src/server/Modules/KitchenService/init.luau` `_spawnSyrupDispensers` resolves `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser`, clones it, calls `PivotTo(syrupsArea.CFrame * CFrame.new(x,0,0))`, and sets `.Liquid.Color` and `.Rim.Color`. The git HEAD version of the spawner used the identical logic, so Jack's model matches the original contract exactly. No repo files were touched, so no gate was run.

## Changes (Studio only, unsaved)
1. Created `ServerStorage.AgentBackups` (Folder).
2. Moved the Rigger-built model to `ServerStorage.AgentBackups.M0_11_RiggerSyrupDispenser`. Attributes BuiltBy and Contract are kept; it was not deleted.
3. Cloned Jack's model unchanged to `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser`. The original in sssArchive is intact (4 children).

## Verification (Play, Server datamodel, then Stop; Studio is back in Edit)
- 18 clones named "<Syrup> Syrup" spawned under `workspace.Assets.Kitchen.Syrups`, one per `Recipes.Syrups`, about 2 studs apart in SyrupsArea space (rel y +0.32, z -0.15). Each has 5 children (Jack's 4 plus the PromptBuilder ProximityPrompt).
- `Liquid.Color == Rim.Color == the Recipes color` on every clone (spot-checked all 18).
- Capture `syrup-area.jpg` (this folder): the bottles stand on the counter in a straight row, tinted per syrup, with the pump spouts toward the viewer on the -Z side.
- Output: no KitchenService, SyrupDispenser or "not found" warnings. The only entries are the existing asset-permission and sound errors, the SpillController/SpillService missing-content warnings, and the Settings SoundService warnings, none related to this change.
- Studio ended in Edit mode. Nothing was saved or published.

## DEC-008 check
None of the blocking conditions applied: one candidate, Liquid and Rim exist by name, placement and orientation match the area's yaw, and no part was built, renamed or edited.

## BuiltBy / CreatedBy inventory (full DataModel attribute scan)
| Path | Attribute | Likely original |
|---|---|---|
| `ServerStorage.AgentBackups.M0_11_RiggerSyrupDispenser` (was `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser`) | BuiltBy = Rigger REVIVAL-001-M0.1 | Jack's `ReplicatedFirst.sssArchive.Services.KitchenService.Assets.SyrupDispenser` (now in use) |
| `ServerStorage.__Backup_OldScriptables_20261013` (Folder) | CreatedBy = Rigger REVIVAL-001-M0.1 | A backup copy of `workspace.OldScriptables` (still present). It holds KitchenFolder, SpillsFolder, `_Assets` and so on. Not a replacement. |

No other instance carries BuiltBy, CreatedBy or any attribute mentioning Rigger, REVIVAL or Agent. The StyleSheet attributes under StylingService were false positives.

## Other M0.1 work with no attribute marker (plan/recon docs plus observation; provenance not proven)
- `ReplicatedStorage.SharedStorage.Effects.PickupBeam` (Beam). The revival plan says "build it" and the recon memo says it was missing, so it is agent-built. No pre-existing Beam or pickup asset exists anywhere in the DataModel.
- `ReplicatedStorage.SharedStorage.Animations.Kitchen.*` (8 Animations). Clones of the flat `Animations` entries (plan: clone, don't move). It reuses Jack's assets.
- `ReplicatedStorage.SharedStorage.Tools.Kitchen.{Mochi, Macaron, IceCream, Pastry, Cups, Mug}`. Restructured from `ReplicatedStorage.ToolsStorage` per plan. Only Mug has a same-name item in ToolsStorage; the other five are new folders. The reuse is partial and should be checked against ToolsStorage.
- `workspace.Assets.Kitchen` (Givers 65, Syrups 1, TrashCans 6). Same contents as `OldScriptables.KitchenFolder`, which now sits in the backup copy only. This is a re-parent of Jack's content.
- `workspace.Assets.Spills` {Areas 3, Tables, Active, Extra, Boards}. The backup's SpillsFolder has {Planes 3, Tables, Active, Extra}. `Areas` has the same child count as `Planes` but a different name, and `Boards` has no counterpart. I did not verify whether Areas is a renamed Planes.
- `workspace["Ordering System"]` {Computers, Status Screens, Staff Screens, Pick Up, CustomerAreas}. Moved from `OldScriptables._Assets.OrderingSystem`; the backup `_Assets` has 8 children versus 7 live.
- `ReplicatedStorage.SharedStorage.Spills.Template` (Cup, Handle, Straw, Liquid, Sparkles) beside `OldTemplate`. The recon memo says Template already existed before M0.1, so there is no evidence of an agent build, but I did not verify its contents.
- Not found, so the code creates them itself: `ReplicatedStorage.ModelStorage`, `workspace.Assets.NPC`.
- The M0.1 captures `Rigger_M01_*` were not located. Its report.md was never written, per `completed.ndjson`.
