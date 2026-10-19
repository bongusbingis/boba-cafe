RESULT: PASS (place save pending: MCP cannot save; Jack presses Ctrl+S / File > Save to Roblox)
Changed (place "jacks project" 89999123284040, Edit mode, no repo code): imports, NPC contract, interior spawns, spill areas, TrashCan tags, legacy group-door collision off.
Gate: n/a (no repo code). Play step skipped per Jack (DEC-019: Prime never Play-tests).
Studio steps later (Jack): Play once, expect CustomerService/SpillService/TrashService/UniformService start without "missing" warns.
Questions for Jack: none blocking. Placement is rough by Jack's instruction; move Assets.NPC parts freely.

## Method note
Imports loaded with `game:GetObjects("rbxasset://bobaimport/<file>.rbxm")` after copying the .rbxm files into each Studio `Versions/*/content/bobaimport/` (File > Insert not drivable via MCP).

## Step 1 imports (all keep BuiltBy="REVIVAL-001-import-v4")
- ReplicatedStorage.SharedStorage.CleanlinessStorage: Spills{Boba, MeltedPopsicle, Donut}, Sparkles, Animations, Tools{Broom, MopBucket, Mop, DishTowel, SprayBottle}, BoardInterface. Required 4 paths: OK.
- SharedStorage.NPCStorage (Folder, BuiltBy=RIG-1, new).Karen: HumanoidDescription (2 accessory + 6 body part descriptions)
- SharedStorage.NPCStorage.Animations: Wave 86079779790658, Confused 95780709532211, BoothSit 139797831117693, ComfySit 99196153493320, CafeSit 124224206331430, CouchSit 99196153493320, Idle 507766951
- SharedStorage.KitchenStorage (Folder, BuiltBy=RIG-1, new).Assets (new).S_DefaultUniform (Shirt), .P_DefaultUniform (Pants)

## Step 2 spawns
Old (Enabled=false, kept): 4x workspace.Map.SpawnLocation at (-203.4,-3.7,461.9) (-238.2,-3.7,518.8) (-186.5,-3.7,433.6) (-221.2,-3.7,490.5).
New under workspace.Map (Neutral, Duration 0, transparent, non-collide, BuiltBy=RIG-1), pathfinding length to Clear Cup (54.6,-9.5,265.9):
| Spawn | Position | Path |
|---|---|---|
| SpawnInterior1 | (55.6,-11.9,260.9) | 6.6 |
| SpawnInterior2 | (49.6,-11.9,260.9) | 9.7 |
| SpawnInterior3 | (61.6,-11.9,266.9) | 11.2 |
| SpawnInterior4 | (61.6,-11.9,260.9) | 12.0 |

## Step 3 NPC contract: workspace.Assets.NPC (BuiltBy=RIG-1)
Entry point given by Jack (4.6,-6.8,323.9), just outside the counter, for testing; floor-snapped to y -11.4. All parts 2x1x2, Anchored, CanCollide/CanQuery/CanTouch false, Transparency 1 (printed check: 0 violations).
- Entry (4.6,-11.4,323.9); Exit (9.6,-11.4,323.9); Path.1 (4.4,-11.4,320.3)
- Queue 1..6: (4.2,316.7) (1.3,315.9) (-1.6,315.1) (-4.5,314.3) (-7.4,313.6) (-10.3,312.8), y -11.4
- Counter 1..5 = the 5 registers of `workspace["Ordering System"].CustomerAreas` nearest Entry: (-8.8,305.9) (-1.5,307.9) (6.0,309.9) (14.0,312.0) (21.9,314.2), y -11.4, LookVector (0.26,0,-0.97) toward the kitchen.
- No OldScriptables.NPCFolder node fit (all 20+ studs away); none cloned.
- Kitchen walking distance to Counter3: Tapioca 87.4, Coffee Machine 91.6 (counter is a barrier; >25 target). Accepted: Jack chose this area; serving is across the counter via ServePrompt.

## Step 4 spills
workspace.Assets.Spills.Areas: 3 existing + 8 new `Floor` parts 16x1x12 at x {-25,-5,15,35} x z {326,340}, y -11.4 = 11. Boards, Active exist.

## Trash can paths
Six Models, all named `Trash`, PrimaryPart = nil, under `workspace.Assets.Kitchen.TrashCans`, pivots: (-33.9,-11.1,327.6) (-19.1,-11.1,282.2) (34.7,-11.1,345.7) (55.0,-11.1,287.3) (-8.2,-11.1,377.6) (65.1,-11.1,383.0). Tag `TrashCan` added to all 6.

## Step 6 path check (PathfindingService, AgentRadius 2)
| i | Entry->Counter i | Counter i->Exit |
|---|---|---|
| 1 | 32.4 | 25.7 |
| 2 | 25.0 | 19.5 |
| 3 | 17.8 | 15.9 |
| 4 | 15.1 | 20.5 |
| 5 | 19.9 | 15.7 |
All Success; Counter->Exit is open floor (straight walk clear).

## Extra (found during the pass)
`workspace.OldScriptables._Assets.GroupDoors.{Kitchen, Ordering, Staff Lines}` were invisible CanCollide walls (legacy group-only doors; only the archived `ReplicatedFirst.StarterPlayerArchive.Controllers.GroupDoorsController` references them) sealing the kitchen for everyone. Set CanCollide=false on their 10 parts, attribute `RIG1_WasCanCollide=true`, nothing deleted. Elevator and Offices group doors untouched.

## Test for Jack
- Spawn inside the kitchen near Clear Cup; walk into kitchen and to the counter freely.
- NPCs appear at Entry, line up (Queue), step to the registers, face the kitchen, leave via Exit.
- Spills appear in the seating/queue floor; mop works.
- Each of the 6 Trash cans shows a working prompt.
- Uniform applies on clock-in; Karen look and Idle/Wave anims play.

Capture: capture-spawn-counter.jpg (contract parts shown temporarily: red Counter, blue Queue, green Entry/Path/Exit).

## Update 2026-10-17: Counter = all 12 registers (Jack)
The 5 placeholder Counter parts were replaced by 12, one per `workspace["Ordering System"].CustomerAreas` part, numbered by distance from Entry. Each has the attribute `SourceArea`, and its LookVector matches its area.
| i | Position | Look | Entry->i | i->Exit |
|---|---|---|---|---|
| 1 | (6.0,-11.4,309.9) | (0.26,0,-0.97) | 17.8 | 15.9 |
| 2 | (14.0,-11.4,312.0) | (0.26,0,-0.97) | 15.1 | 20.5 |
| 3 | (-1.5,-11.4,307.9) | (0.26,0,-0.97) | 25.0 | 19.5 |
| 4 | (21.9,-11.4,314.2) | (0.26,0,-0.97) | 19.9 | 15.7 |
| 5 | (-8.8,-11.4,305.9) | (0.26,0,-0.97) | 32.4 | 25.7 |
| 6 | (29.8,-11.4,316.3) | (0.26,0,-0.97) | 26.3 | 21.6 |
| 7 | (-16.0,-11.4,304.0) | (0.26,0,-0.97) | 29.5 | 44.6 |
| 8 | (38.6,-11.4,318.6) | (0.26,0,-0.97) | 34.4 | 29.5 |
| 9 | (-23.8,-11.4,301.9) | (0.26,0,-0.97) | 35.9 | 41.3 |
| 10 | (-31.3,-11.4,299.9) | (0.26,0,-0.97) | 43.2 | 48.4 |
| 11 | (-39.5,-11.4,297.7) | (0.26,0,-0.97) | 51.4 | 56.4 |
| 12 | (-44.1,-11.4,284.9) | (0.97,0,0.26) | 68.9 | 76.9 |
NOT VERIFIED: the straight walk Counter i -> Exit for 7 and 9-12 (path > straight line; Studio entered Play before the raycast check). In the worst case the 6 s PivotTo fallback covers it.
