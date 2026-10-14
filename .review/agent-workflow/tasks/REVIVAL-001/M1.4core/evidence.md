RESULT: PASS
# REVIVAL-001-M1.4core: CustomerService core (Mason)

Gate PASS and the pure rules pass 27/27 under lune. The service itself (world resolve, walking, collision groups, bubble) has NOT run in Studio, because the world contract does not exist yet and this lane had no Studio. That part is UNVERIFIED until Gauge runs the smoke below.

HEAD at finish: `041888d` (REVIVAL-001 M1.3c/d). All files below are new and untracked; nothing existing was edited. `src/server/init.server.luau` was not touched: `Knit.AddServicesDeep(script.Modules)` requires every ModuleScript under `Modules/`, and `rojo sourcemap` shows `CustomerService` (init) with `Npc` and `Rules` children, so the service loads with no registry edit. `TESTS_ENABLED` untouched (still `false`).

## Files and sha256
```
51f16809166866e610b99f585966ceb716c9f22f07aea66e2b62dd31ec381d03  src/shared/Configuration/CustomerConfig.luau
b6fb927dd2e4eed4c529e74079f1f2289d93067b4b6d5e418cf5622886daaac9  src/server/Modules/CustomerService/Rules.luau
fd7ab360707ff23f67163396f811a41e2ecbe12277c72c5c90e71660a25ee90b  src/server/Modules/CustomerService/Npc.luau
8c4ff8e466e7b87244f61ea95579b951b698650141a8219f0cbded70e4537bb6  src/server/Modules/CustomerService/init.luau
b83af4e4917c60cdf2dc3d68087ab414f1c2110bd02c405c959ff9a8cddb6940  src/server/Tests/CustomerService.spec.luau
```

## Gate (`scripts/gate.sh <the 5 files>`)
```
PASS  src/shared/Configuration/CustomerConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/Rules.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/Npc.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/CustomerService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /var/folders/7d/n36x8s6n387bhfdj5j1z0s500000gn/T/gate-build.rbxl
GATE: PASS
```

## Other checks
- lune 0.10.5 (from `~/.rokit/tool-storage`; shim with a mini describe/it/expect in `/private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m14core-shim/`): `CustomerService.spec` logic, 27 passes, 0 failures. This is a shim, not TestEZ; Gauge still runs the real suite.
- The same shim ran `Rules.PickOrder()` 200 times through the real `OrderSpec.FromMenuItem` with defs copied from `Menu.luau`. Every pick resolved. Labels seen: `{Small|Medium|Large} Custom Boba` (Syrup Classic Milk Tea, Tapioca Normal), `{S|M|L} Regular` (Iced=false), `Fudge Brownie` (Grab). The real `FromOrderItem` against the live Menu is UNVERIFIED (Menu needs `SelectorModels`).

## API
Config: `CustomerConfig` (shared). Values: `SERVER_CAP`, `SLOTS_PER_BARISTA`, `LINE_BASE`, `LINE_BARISTAS_PER_EXTRA`, `SPAWN_GAP_SECONDS`, `PATIENCE_BASE_SECONDS`, `PATIENCE_BONUS_SECONDS` (by Menu category), `PATIENCE_GRAB_BONUS_SECONDS`, `PATIENCE_YELLOW_FRACTION`, `PATIENCE_RED_FRACTION`, `SIZE_WEIGHTS`, `ORDER_POOL`, `PAY_TABLE` (empty). Every value is commented TUNING. No BobaBucks or XP numbers anywhere.

Rules (pure, `CustomerService/Rules.luau`):
- `Rules.PacingTarget(baristas, config?) -> number` (1 -> 2, 5 -> 7, 20 -> 16, 40 -> 16, 0 -> 0)
- `Rules.PatienceSeconds(items: {OrderItem}, config?) -> number` (boba 70, coffee 60, brownie 55, boba+brownie 80)
- `Rules.PatienceState(fractionLeft, config?) -> "Green" | "Yellow" | "Red"` (at or below 0.5 / 0.25)
- `Rules.PickOrder(rng?: () -> number, config?) -> OrderItem` (rng returns [0,1); pool pick uses roll 1, size uses roll 2 for Sized entries; returns a fresh table)

Service (`CustomerService`, Knit):
- `CustomerService:GetWaitingCustomers() -> {Npc}`: NPCs at a counter spot, in spot order. Empty when disabled.
- `CustomerService.CustomerLeft`: GoodSignal `(npc, reason)`, once per NPC when it stops waiting. Reasons now: `"PatienceOut"`, `"Despawned"` (stuck, error or early destroy). Serve work adds `"Served"`.
- `CustomerService.Enabled`: false when the contract is missing.
- NPC fields: `Model`, `Order` (pool order item), `Spec` (OrderSpec), `State` (`Walking | Queued | AtCounter | Leaving`), `PatienceTotal`, `CounterSpot`, `Left`. `npc:Leave(reason)` is the public way to make one leave. Model attributes: `BuiltBy="REVIVAL-001-M1.4core"`, `State`, `PatienceTotal`, `PatienceEnd` (server time, set on arrival at the counter).
- Runtime content: `workspace.Customers` folder (created when enabled) holds the NPC models. Collision groups `NPC` and `CafePlayers` are registered at runtime.

## Behaviour implemented
- KnitStart resolves `workspace.Assets.NPC.{Entry, Exit, Path, Queue, Counter}` with `WorldPath.waitFor`, one shared 10 s budget. If anything is missing: one `warn` naming it, `Enabled` stays false, no folder, no loop, no errors.
- Pacing loop (1 s tick): clocked-in count from `ShiftService:IsClockedIn`; spawn one NPC while `present < PacingTarget`, line has room, and the 3 s gap has passed. Never spawns into a full queue. `present` counts NPCs until destroyed (including ones leaving).
- NPC: build rig, spawn at Entry, walk Path 1..n, join the line (the position is reserved at spawn), walk to its queue spot; the front NPC takes the lowest free Counter spot and walks there (queue shifts forward behind it), faces the Counter part's rotation, patience ticks down (bar green, yellow at 50%, red at 25%), pauses while 0 baristas are clocked in, on zero the NPC leaves (no penalty, no payout), walks to Exit and is destroyed.
- Walking is `Humanoid:MoveTo` per node. After 6 s a segment is finished with `PivotTo`. 3 PivotTo fallbacks in a row raise an error: the NPC is despawned with a warn and its spots are freed. The whole NPC thread is in `pcall`.
- Model: `buildNpcModel()` is the one builder (`CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), R15)`), marked `-- PENDING JACK Q25: NPC look`. Climbing and swimming off, default name tag hidden.
- Collision: NPC parts in group `NPC`; `NPC` collides with neither `CafePlayers` nor `NPC`, and still collides with Default (floor). Player characters are moved into `CafePlayers` (current parts plus parts added later) via `PlayerAdded` / `PlayerRemoving`. If group setup fails the service stays disabled with a warn (NPCs that block the counter are worse than none).
- Network owner: `SetNetworkOwner(nil)` after parenting, in a pcall.
- Bubble: server-built `BillboardGui` on the head. `Spec.Label` plus a second line with syrup, tapioca, Iced, Sugar when present (for example `Medium Custom Boba` / `Classic Milk Tea, Normal tapioca`), and a patience bar. Colours and font from `Styles` tokens: CREAM card, GREEN stroke, GREEN_DEEP text, GRAY track, bar GREEN / GOLD_MID / RED, FONT_FREDOKA, CORNER_BUTTON / CORNER_FULL. No colour chip (see questions).

## Stubbed or not built (PENDING JACK)
- Assignment, Rescue, Serve prompt, `FindServeTools`, tickets, `TicketChanged`: Q1, Q2 (M1.4e).
- Payout, combo, speed bonus: Q5/Q6. `PAY_TABLE` is empty with the comment `PENDING JACK Q5/Q6 (economy gate)`.
- First-session script (scripted first 3 orders, customer #1 placed directly, paused patience): Q4. No `CustomersServed` stat (ProfileTemplate untouched).
- NPC look, impatient emote, sad emote: Q25. Rig is the default R15 body.
- "Never the same spec twice in a row per barista": needs assignment (Q1).
- World contract authoring (M1.4a): Q7/Q8. The parts do not exist.

## Questions for Jack (recorded, not decided)
1. **Sizes (Q3).** The pool follows design 4.4: boba and coffee get Small 30 / Medium 40 / Large 30. M1.1's example boba shape is fixed `Size="Medium"`, and M1.3c expects a Small Regular for the scripted third order. If Q3 says one size, set `SIZE_WEIGHTS` to a single entry. Config only.
2. **Leaving route.** The NPC walks straight from its counter spot to `Exit` with `MoveTo` (PivotTo after 6 s). The contract has no exit lane. If `Exit` is not in a straight walkable line from the counter, the NPC will teleport to it after 6 s. Does Jack or the M1.4a Rigger want an exit lane (for example Path reversed) in the contract?
3. **Patience start.** Design 4.5 starts the clock at assignment. Assignment does not exist (Q1), so patience starts when the NPC arrives at its counter spot. Queued NPCs show a full bar. Revisit with Q1.
4. **Bubble wording.** Design 4.4 timeline shows "Medium · Classic Milk Tea Boba", but `OrderSpec.Label` is "Medium Custom Boba" (the flavour is not in it). I show the label plus a flavour line so the order is readable. The wording is a placeholder, and the design's colour chip is not built (that needs the syrup colours from Menu views; it is M1.4e).
5. **Collision groups touch player characters.** There is no way to stop NPCs colliding with players without a second group for players, so every character's parts are set to group `CafePlayers`. I could not check whether the place already defines collision groups or sets a group on characters. If it does, Jack or a Rigger should look before Gauge runs this.
6. **Contract strictness.** Entry and Exit must be BaseParts, and `Path`, `Queue`, `Counter` must each hold at least one BasePart named with a number. An empty `Path` disables the service, even though a straight Entry-to-Queue walk would be legal. Say if an empty Path should be allowed.
7. **Counter facing.** On arrival the NPC takes the Counter part's CFrame rotation (the part's LookVector is the NPC's facing), because the contract says Counter parts "face the kitchen". Confirm that is how the Rigger will orient them.
8. **Counter order.** The front NPC takes the lowest-numbered free Counter spot.
9. **Docs.** `docs/SYSTEMS.md` needs a Quill follow-up: the contract paths above, the runtime `workspace.Customers` folder, and the `NPC` / `CafePlayers` collision groups (CONVENTIONS requires paths to be named there). Outside this lane's write scope.

## Studio smoke procedure for Gauge (needs the Rigger-free temporary contract)
The real `workspace.Assets.NPC` does not exist (M1.4a, Q7/Q8). The aim here is only to exercise the mechanics. These parts are scratch, are not a layout proposal, and the place must never be saved with them.

Make the parts in Edit mode, so they exist when Play starts and KnitStart (10 s budget) finds them. In Edit mode run `execute_luau` (or the command bar), after first inspecting `workspace.OldScriptables.NPCFolder` (Spawn, Traversable x16, OrderPickup, WanderPlanes per design Q8; the node classes are not confirmed, so the helper reads Part, Model or Attachment):
```lua
local nodes = workspace.OldScriptables.NPCFolder
local function posOf(i)
	if i:IsA("BasePart") then return i.Position
	elseif i:IsA("Model") then return i:GetPivot().Position
	elseif i:IsA("Attachment") then return i.WorldPosition end
end
local root = Instance.new("Folder")
root.Name = "NPC"
root:SetAttribute("TempSmoke", true) -- remember to delete
local function group(name) local f = Instance.new("Folder"); f.Name = name; f.Parent = root; return f end
local function mk(parent, name, pos)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.CanCollide, p.Transparency = name, true, false, 1
	p.Size, p.Position, p.Parent = Vector3.new(2, 1, 2), pos, parent
end
local trav = {}
for _, c in nodes.Traversable:GetChildren() do table.insert(trav, c) end   -- adjust if Traversable is the node itself
table.sort(trav, function(a, b) return a.Name < b.Name end)
local spawnPos = posOf(nodes.Spawn)
mk(root, "Entry", spawnPos)
mk(root, "Exit", spawnPos)
local path, queue, counter = group("Path"), group("Queue"), group("Counter")
mk(path, "1", posOf(trav[1])); mk(path, "2", posOf(trav[2]))
for i = 1, 3 do mk(queue, tostring(i), posOf(trav[2 + i])) end   -- 1 = front
for i = 1, 2 do mk(counter, tostring(i), posOf(trav[5 + i])) end
root.Parent = workspace.Assets
```
Pick different Traversable nodes if these are not a walkable chain; a stalled walk is itself a useful result (PivotTo fallback). Finish with `workspace.Assets.NPC:Destroy()` in Edit mode and check `workspace.Assets:FindFirstChild("NPC") == nil`. Do not save.

Checks (Play, solo, default clocked in):
1. About 10 s in, `workspace.Customers` holds 2 `Customer` models (target for 1 barista is 2), each with `BuiltBy = "REVIVAL-001-M1.4core"`. Output has 0 errors and no `[CustomerService]` warn.
2. One NPC reaches a counter spot: `State = "AtCounter"`, `PatienceTotal` 55 / 60 / 70 (brownie / coffee / boba), `PatienceEnd` set, bubble visible with the label and a green bar that shrinks, yellow at 50%, red at 25%. The second NPC stands in line or takes the next counter spot.
3. Collision: `HumanoidRootPart.CollisionGroup` is `"NPC"` on an NPC and `"CafePlayers"` on the player. The player walks through an NPC without being pushed or blocked.
4. Patience out: the NPC leaves, walks to Exit, is destroyed, and a replacement spawns about 3 s later. The count stays 2. Server command bar: `local s = require(game.ReplicatedStorage.Packages.Knit).GetService("CustomerService"); s.CustomerLeft:Connect(print); print(#s:GetWaitingCustomers())` prints `(npc, "PatienceOut")` once per leaver.
5. Clock out (`ShiftService:SetClockedIn(player, false)` from the server command bar): no new spawns, and `PatienceEnd` keeps moving later (patience paused). Clock back in: it resumes.
6. Missing contract: rename `workspace.Assets.NPC` to `NPCx` before Play. Exactly one warn `[CustomerService] NPC customers disabled; missing authored content: ...` within about 10 s, no `workspace.Customers`, no NPCs, 0 errors, and the kitchen still works.
7. 10-minute soak with 1 barista: `#workspace.Customers:GetChildren() <= 2` throughout, no growth in instance count.
8. TestEZ: `workspace:SetAttribute("RunTests", true)`, Play, expect the `CustomerService` spec (27 cases) to pass.
9. 5, 20 and 40 baristas need multiple clients and are UNVERIFIED in solo Studio; `PacingTarget` for those counts is covered by the table tests.

## UNVERIFIED
- Everything that needs Studio: model build, bubble rendering, MoveTo behaviour and `MoveToFinished` timing, the collision groups, `SetNetworkOwner`, the disabled path, the soak.
- Luau type check (`--!strict`): no analyzer was available here, only selene, stylua and the rojo build.
- Real TestEZ run of the new spec.

## Risks
- `CreateHumanoidModelFromDescription` is a web call per spawn (gap is at least 3 s). If it fails, a single warn is printed and spawning keeps retrying silently.
- The `CafePlayers` group assignment touches every character (see question 5).
- A stalled walk teleports the NPC after 6 s, so a badly authored contract looks like NPCs popping between nodes rather than failing loudly.
- `PacingTarget` can briefly exceed the target after baristas clock out (NPCs are not culled), as design 4.2 says nothing about culling.
