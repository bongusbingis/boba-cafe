# PHONE-RECON: Read-only inventory of the legacy Boba Phone and Jack's raw React port
Model: sonnet (Lens/Rigger, read-only)   Studio: YES (exclusive, edit mode)   Depends on: DEC-040   Size: M

## Goal
Give the Architect everything needed to write the BOBA-PHONE port packet without guessing (DEC-008):
the legacy phone's structure and scripts, the "Boba" app's ordering flow, Jack's `__REACT__PHONE` raw port, any phone Tool, and how it all maps to the current ordering system.

## Read (repo)
- `AGENTS.md`; `.review/agent-workflow/decisions.md` DEC-040; `docs/STYLE.md` (skim).
- `src/server/Modules/OrderService.luau`: `OrderService.Client:CreateOrder` and the result type; `src/shared/UI/Pages/MobileOrder/init.luau` and `src/shared/UI/Pages/Ordering/init.luau` (how they build the `orderItems` request).
- `src/shared/UI/Components/Core/Hud/TopBar.luau` (register prompt, lines ~55-90).
- `default.project.json` (which Studio paths are Rojo-managed; place content is not).

## Studio (edit mode, read-only)
Target "jacks project" (placeId 89999123284040). Never Play, never TestEZ (DEC-019). Never edit or save the place.
1. `StarterGui.UIArchive.OldUI.BobaPhone`: full tree (class, name, key properties for top-level frames; summarized below depth 3). List every app (frames/buttons) and mark the "Boba" app.
2. Every Script/LocalScript/ModuleScript under BobaPhone: path, line count, and save the full source to `tasks/REVIVAL-001/PHONE-RECON/legacy-src/<path-with-dots>.luau`. For each, list remotes/services/instances it references (ReplicatedStorage paths, RemoteEvents/Functions, `require`s, menu data sources).
3. The Boba app's ordering flow step by step: screens, menu data source (where items/prices/options come from), cart, submit (what remote and payload), order status/pickup display.
4. Find `__REACT__PHONE` (search the whole DataModel by name). Record its path, its tree of ModuleScripts, line counts, what React/Roact library it requires and from where, and save each source to `PHONE-RECON/react-port/<path>.luau`. Note obvious problems (wrong React require, Roact vs React API, hard-coded asset ids, missing modules).
5. Any phone Tool: search StarterPack, ReplicatedStorage, ServerStorage, workspace, Lighting, UIArchive for Tools or models named like Phone/BobaPhone. Record path, Handle/mesh asset ids, any scripts in it. If none exists, record exactly where you searched (never "doesn't exist").
6. Asset ids (images/meshes/sounds) used by the Boba app; list them.
7. Map legacy -> current: for each legacy remote/data source the Boba app uses, name the current equivalent (`OrderService:CreateOrder`, menu config in `src/shared/Configuration`, etc.) or "no equivalent".

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/PHONE-RECON/` only (evidence.md, legacy-src/, react-port/).
- No repo source edits, no Studio edits, no saves. If you create any temporary instance, destroy it and confirm StarterGui/ReplicatedStorage child counts are unchanged.

## Done when
- evidence.md has items 1-7, with paths to every saved source file.
- A short "port risks" list: what will need real work (not just mechanical) to run on the current ordering system.

## STOP-AND-ASK
- Play mode, or anything that would need an edit or save: stop and report BLOCKED.
