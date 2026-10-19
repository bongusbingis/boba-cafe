# Q-DOCS-M1: Document the M1 systems
Model: haiku   Studio: no   Depends on: RIG-1, M1.4f, TRASH, NPC-LOOK, SPILLS, Q14-GATES   Size: M

## Goal
`docs/SYSTEMS.md` and `docs/ARCHITECTURE.md` describe what M1 built, with every world path named (CONVENTIONS rule).

## Read (only these)
- `docs/SYSTEMS.md` lines 110-165 and 253-270 (Ordering, Kitchen, Spills sections and the format they use)
- `docs/ARCHITECTURE.md`: `grep -n "^## \|^### "` first, then only the section that lists services/modules and the world paths
- Evidence files, headings and contract sections only: `tasks/REVIVAL-001/M1.4core/evidence.md` (API, Behaviour), `M1.4e/evidence.md` (ticket table), `M1.4f/evidence.md`, `RIG-1/evidence.md` (node list, trash paths), `SPILLS/evidence.md`, `TRASH/evidence.md`, `NPC-LOOK/evidence.md`, `Q14-GATES/evidence.md`
- `src/shared/Ordering/OrderSpec.luau` lines 1-60 (the type and header comment) and `src/server/Modules/OrderService.luau` lines 60-100 (launch allowlist, if R1-FIX added one: `grep -n "ALLOW\|Launch"`)
- `src/client/Modules/KitchenGuidance.luau` lines 1-40

## Write scope
- `docs/SYSTEMS.md`
- `docs/ARCHITECTURE.md`

## Steps
1. SYSTEMS.md, in the Ordering section: add "OrderSpec and tool attributes" (attributes `Item`, `Size`, `Syrup`, `Tapioca`, `Iced`, `Sugar`, `Served`; where each is written; grading Perfect/Close/Wrong) and "Auto-match deposit" (`FindServeTools`, synchronous, `Served` marks a picked-up drink) and "Launch allowlist" (where it lives, what it blocks). Use the same heading level and table style as neighbouring entries.
2. SYSTEMS.md, new section "Customers (NPCs)": `CustomerService` contract paths `workspace.Assets.NPC.{Entry, Exit, Path, Queue, Counter}` (with the part rules from the RIG-1 evidence), the runtime folder `workspace.Customers`, collision groups `NPC` and `CafePlayers`, the ticket table from M1.4e, the Serve/Rescue prompt `ServePrompt`, `UniformService`, `TrashService` with the six can paths, and the `PAY_TABLE` values labelled PROPOSED.
3. SYSTEMS.md, Kitchen section: add `KitchenGuidance` (client, pure logic: Steps, Highlight, beam, toasts) and the Q14 attribute gates with the new holds (Coffee Machine 4 s, Ice Machine 3 s). In the Spills section change the storage path to `ReplicatedStorage.SharedStorage.CleanlinessStorage`.
4. SYSTEMS.md: list the new world paths from RIG-1: `SharedStorage.CleanlinessStorage`, `SharedStorage.NPCStorage.{Karen, Animations}`, `SharedStorage.KitchenStorage.Assets.{S_DefaultUniform, P_DefaultUniform}`, interior `SpawnInterior1..4`.
5. ARCHITECTURE.md: add `CustomerService`, `UniformService`, `TrashService`, `AnalyticsEvents` (if present) to the service list in the same format as existing rows, and `KitchenGuidance`, `CustomerConfig`, `CustomerDialogue` to the module lists.
6. Do not edit any file under `src/`.

## Done when
- Every path in steps 2-4 appears in SYSTEMS.md, spelled as in the RIG-1 evidence.
- Existing headings and entries are unchanged except the Spills storage path.

## Checks to run
- `grep -n "CleanlinessStorage\|workspace.Customers\|CafePlayers\|KitchenGuidance\|ServePrompt" docs/SYSTEMS.md` returns a hit for each.

## STOP-AND-ASK
- An evidence file named above is missing: list which and write only the sections you can support.

## Evidence
`tasks/REVIVAL-001/Q-DOCS-M1/evidence.md`
