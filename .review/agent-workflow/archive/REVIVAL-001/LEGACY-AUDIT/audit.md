# M5 Legacy Workspace Scripts Audit Report

**Date:** 2026-10-18  
**Auditor:** Scout / Sentry Specialist  
**Target:** Live Studio Place `89999123284040` (`jacks project`)  
**Scope:** `Workspace.OldScriptables` and `Workspace.Map`  
**Task Packet:** `REVIVAL-001/packets/M5-LEGACY-AUDIT.md`  

---

## 1. Executive Summary

A comprehensive, non-destructive audit of legacy workspace scripts in the Boba Cafe place file was performed using Studio MCP inspection tools (`script_read`, `execute_luau`, and `search_game_tree`). 

The audit evaluated all 7 target scripts specified in packet `M5-LEGACY-AUDIT.md`, plus 14 additional legacy scripts discovered in the surrounding hierarchy (`Workspace.Map` and `Workspace.OldScriptables.AdvertisementsFolder`). Each script was analyzed for obsolete pass/product prompts, deprecated API calls, infinite yields/loops, runtime exceptions, and conflicts with the modern Knit/Luau revival architecture.

### Key Audit Findings
1. **Critical Live Exceptions (`IslandTeleporter` & `Celebrity Billboard`):**
   - `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script` is currently **ENABLED** (`Disabled = false`). Line 1 has the framework require commented out (`--local Boba = ...`), but line 4 immediately indexes global `Boba:GetReplicaByClassToken(...)`. Every time a player activates the proximity prompt, the server throws `attempt to index nil with 'GetReplicaByClassToken'`.
   - `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.Celebrity.Script` has the identical bug: enabled, require commented out, and throws an unhandled nil indexing error on click.
2. **Critical Monetization Hazard (Unhandled Robux Purchases):**
   - Two scripts under `Workspace.Map.Model.Part.Script` are currently **ENABLED** and prompt Developer Product purchases:
     - `1120964689` ("Huge Fireworks", 2,250 Robux)
     - `947356322` ("Small Fireworks", 500 Robux)
   - **No receipt processing exists** in the revival codebase (`ProcessReceipt` is not implemented for these IDs). If a player purchases Robux at these prompts, funds will be taken without delivering items or acknowledging the receipt. This directly violates product safety invariants and requires immediate disabling.
3. **Startup Infinite Yields (Missing `ReplicatedStorage.Boba`):**
   - `ElevatorScript`, `ZiplineHandler`, and both `SlideSitPart.Script` instances require `ReplicatedStorage:WaitForChild("Boba")`. Because the legacy `Boba` root module has been migrated/removed, any enabled script requiring this module hangs permanently at startup, producing warning spam in server output.
4. **Server CPU & Replication Overhead (`Workspace.Map.Model.Script`):**
   - The giant rotating Boba cup script runs an infinite 24,000-step loop at server frame-rate using deprecated `wait()`, calling `SetPrimaryPartCFrame` via a temporary `CFrameValue` injected into `ServerStorage`. This creates constant, unnecessary server-to-client network replication for purely cosmetic rotation.

---

## 2. Complete Script Audit Matrix

| # | Script Path | State | Triggers / Purpose | Product / Pass IDs | Key Defects & Incompatibilities | Risk | Classification |
|---|---|---|---|---|---|---|---|
| **1** | `Workspace.OldScriptables.ElevatorFolder.ElevatorScript` | **Disabled** | ProximityPrompt on Floor1 & Floor2 calling elevator teleport | None | Requires missing `ReplicatedStorage.Boba`; depends on legacy `ReplicaService`; direct ProximityPrompt table indexing | Low | `RECOMMEND_DISABLE` |
| **2** | `Workspace.OldScriptables.ZiplineFolder.ZiplineHandler` | **Disabled** | Generates zipline ropes, prompts "Ride Zipline", tweens player | Fun Pass (12385799) referenced via legacy service | Requires missing `ReplicatedStorage.Boba`; calls missing `FunPassService` and `PromptService`; deprecated `Humanoid:LoadAnimation`, `.magnitude`, `Instance.new(..., parent)` | Low | `RECOMMEND_DISABLE` |
| **3** | `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script` | **ENABLED** | ProximityPrompt opening Island Teleport UI | None | Require commented out; fatal runtime error on trigger: `attempt to index nil with 'GetReplicaByClassToken'`; calls legacy `MainUIControlReplica` | **CRITICAL** | `RECOMMEND_DISABLE` |
| **4** | `Workspace.Map.FountainsFolder.Script` | **Disabled** | Infinite loop toggling ParticleEmitters every 5s | None | References nonexistent `workspace.Fountain`; fatal error `pairs(nil)` on start; spams print statements; deprecated `wait()` | Low | `RECOMMEND_DISABLE` |
| **5a** | `Workspace.Map.SlideSitPart.Script` (Instance 1) | **Disabled** | Touched: forces `Humanoid.Sit = true` & advances quest | None | Requires missing `ReplicatedStorage.Boba`; yields forever at line 1; calls missing `QuestService:AdvanceQuest`; uses `object.parent` | Low | `RECOMMEND_DISABLE` |
| **5b** | `Workspace.Map.SlideSitPart.Script` (Instance 2) | **Disabled** | Touched: forces `Humanoid.Sit = true` & advances quest | None | Identical to Instance 1 | Low | `RECOMMEND_DISABLE` |
| **6** | `Workspace.Map.Model.Script` | **ENABLED** | Server-side infinite CFrame rotation loop for giant Boba cup | None | Runs continuous server-side CFrame replication (24k steps); deprecated `wait()`, `SetPrimaryPartCFrame`, `GetPrimaryPartCFrame`; creates `CFrameValue` in `ServerStorage` | Medium | `NEEDS_UPDATE` |
| **7** | `Workspace.Map.Part.Script` | **ENABLED** | Touched: forces `Humanoid.Sit = true` | None | Deprecated `:connect(...)`; global variable leak (`brick`); lacks debounce; repeatedly forces sit | Low | `SAFE_TO_KEEP` |
| **8a** | `Workspace.Map.Model.Part.Script` (Fireworks Stand - Huge) | **ENABLED** | ProximityPrompt: prompts Robux developer product | Product `1120964689` (2,250 Robux) | **No receipt processor**; unhandled developer product charges real Robux without delivering fireworks; unauthorized monetization | **CRITICAL** | `RECOMMEND_DISABLE` |
| **8b** | `Workspace.Map.Model.Part.Script` (Fireworks Stand - Small) | **ENABLED** | ProximityPrompt: prompts Robux developer product | Product `947356322` (500 Robux) | **No receipt processor**; unhandled developer product charges real Robux without delivering fireworks; unauthorized monetization | **CRITICAL** | `RECOMMEND_DISABLE` |
| **9** | `Workspace.Map.Model.Liquid.Script` | **ENABLED** | Tweens Boba cup liquid color to salmon | None | Harmless cosmetic color tween; absurd repeat count (`753475938457843579348573`); whitespace bloat | Low | `SAFE_TO_KEEP` |
| **10** | `Workspace.Map.Model.Model.MeshPart.Script` | **ENABLED** | ClickDetector toggles ParticleEmitter | None | Self-contained; clean logic | Low | `SAFE_TO_KEEP` |
| **11** | `Workspace.Map.Pika.Handle.Script` | **ENABLED** | ClickDetector plays sound | None | Ineffective debounce flag; self-contained harmless cosmetic sound | Low | `SAFE_TO_KEEP` |
| **12** | `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.*` (11 scripts) | **ENABLED** | Billboard display & PromptGamePassPurchase on click | Passes: 40973940, 43707849, 12385760, 12385781, 14067340, 15243046, 12385796, 12385742, 12385818, 12385799, 6202153 | Un-pcalled `GetProductInfo` on server startup; legacy passes may conflict with revival shop catalog; redundant with modern UI shop | Medium | `RECOMMEND_DISABLE` |
| **13** | `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.Celebrity.Script` | **ENABLED** | ClickDetector prompts Celebrity pass | Pass 6202153 | Require commented out; fatal runtime error on click: `attempt to index nil with 'GetReplicaByClassToken'` | **HIGH** | `RECOMMEND_DISABLE` |
| **14** | `Workspace.OldScriptables.AdvertisementsFolder.Products.Donate!.Script` | **ENABLED** | SurfaceGui donation board listing 12 donation products | Products: 928273533, 55777641, 680670445, 680670692, 680670865, 680671117, 680671325, 680671544, 680671832, 928275862, 928276567, 1168137385 | Un-pcalled loop of 12 `GetProductInfo` requests at startup; donation receipt handling unverified | Medium | `RECOMMEND_DISABLE` |

---

## 3. Detailed Technical Analysis

### 3.1. Primary Target Scripts

#### Script 1: `Workspace.OldScriptables.ElevatorFolder.ElevatorScript`
* **Status:** `Disabled = true`
* **Source:**
  ```luau
  local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
  local ReplicaService = require(Boba.Packages.ReplicaService)
  local TweenService = game:GetService("TweenService")
  local Floors = {}
  local FloorList = {}
  local CurrentFloor = nil
  local Debounce = false
  
  local elevatorReplica = ReplicaService.NewReplica({
      ClassToken = ReplicaService.NewClassToken("ElevatorReplica"),
      Data = {},
      Replication = "All",
  })
  
  local floorOne = script.Parent.Floors.Floor1
  local floorTwo = script.Parent.Floors.Floor2
  
  local proximityPrompts = {
      [floorOne.CallElevator.ProximityPrompt] = floorTwo.Teleport,
      [floorTwo.CallElevator.ProximityPrompt] = floorOne.Teleport,
  }
  
  for proximityPrompt:ProximityPrompt, teleportPart:Part in pairs(proximityPrompts) do
      proximityPrompt.Triggered:Connect(function(player:Player)
          if player.Character then
              elevatorReplica:FireClient(player, teleportPart)
          end
      end)
  end
  ```
* **Analysis:**
  - If re-enabled, it hangs indefinitely at line 1 (`WaitForChild("Boba")`).
  - Architecture relies on deprecated `ReplicaService` to signal the client to tween/teleport to the target floor.
  - In Knit revival architecture, elevator movement/teleportation belongs in a dedicated `ElevatorService` or `ZoneService`.
* **Recommendation:** `RECOMMEND_DISABLE`. Keep disabled or remove script when elevator functionality is ported to Knit.

---

#### Script 2: `Workspace.OldScriptables.ZiplineFolder.ZiplineHandler`
* **Status:** `Disabled = true`
* **Source Excerpt:**
  ```luau
  local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
  local TweenService = game:GetService("TweenService")
  local MarketPlaceService = game:GetService("MarketplaceService")
  ...
  proximity.Triggered:Connect(function(player)
      if Boba.Services.FunPassService:HasFunPass(player) or true then -- TEMPORARY FREE 
          if player.Character then
              local clonedHandle = script.Zipline:Clone()
              clonedHandle.Parent = player.Character
              ...
              player.Character.HumanoidRootPart.Anchored = true
              local anim = player.Character.Humanoid:LoadAnimation(script.Animation)
              anim:Play()
  ```
* **Analysis:**
  - Hangs at line 1 on `WaitForChild("Boba")`.
  - Deprecated APIs: `(point1 - point2).magnitude` (lowercase `magnitude` deprecated in Luau), `Instance.new("Part", path)` (2-argument constructor is an anti-pattern), `Humanoid:LoadAnimation` (deprecated; must use `Animator:LoadAnimation`).
  - Physics anti-pattern: Anchoring `HumanoidRootPart` on server and running a CFrame tween while listening to `.Changed` can cause character rubber-banding and physics desynchronization.
  - References legacy `FunPassService` and `PromptService`.
* **Recommendation:** `RECOMMEND_DISABLE`. Keep disabled. If zipline feature is revived in a later milestone, implement via a client-authoritative `ZiplineController` with clean animation playback.

---

#### Script 3: `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script`
* **Status:** `Disabled = false` (**ACTIVE IN LIVE PLACE**)
* **Source:**
  ```luau
  --local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
  
  script.Parent.ProximityPrompt.Triggered:Connect(function(player)
      local MainUIControlReplica = Boba:GetReplicaByClassToken("MainUIControlReplica")
      MainUIControlReplica:FireClient(player, "OpenCloseMenu", "IslandTeleport")
  end)
  ```
* **Analysis:**
  - **Fatal Runtime Error:** The require line was commented out during legacy refactoring, but `Boba` is still indexed on line 4.
  - Whenever a player interacts with the ProximityPrompt on the Island Teleporter, the server throws an unhandled error:
    `attempt to index nil with 'GetReplicaByClassToken'`
  - Leaves the player stuck with no feedback, degrading user experience.
* **Recommendation:** `RECOMMEND_DISABLE` (**IMMEDIATE ACTION**). Set `Disabled = true` in Studio immediately to stop runtime errors.

---

#### Script 4: `Workspace.Map.FountainsFolder.Script`
* **Status:** `Disabled = true`
* **Source:**
  ```luau
  while true do
      wait(.1)
      for i, model in pairs(workspace.Fountain:FindFirstChild()) do
          if model:IsA('ParticleEmitter') then
              print("off")
              model.Enabled = true
              wait(5)
              print("on")
              model.Enabled = false
              wait(5)
          end
      end
  end
  ```
* **Analysis:**
  - **Fatal Syntax/Reference Error:** `workspace.Fountain` does not exist in the DataModel (only `Workspace.Map.FountainsFolder` exists).
  - Calling `:FindFirstChild()` with no arguments returns `nil`, and `pairs(nil)` throws `bad argument #1 to 'pairs' (table expected, got nil)`.
  - Inverted print statements: logs `"off"` when enabling particles, and `"on"` when disabling them.
  - Uses deprecated `wait()`.
* **Recommendation:** `RECOMMEND_DISABLE`. Keep disabled or delete. Particle emitters can remain permanently enabled or be animated client-side.

---

#### Script 5: `Workspace.Map.SlideSitPart.Script` (2 Duplicate Parts)
* **Status:** `Disabled = true` (Both instances)
* **Source:**
  ```luau
  local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
  script.Parent.Touched:Connect(function(object)
      local player = game:GetService("Players"):GetPlayerFromCharacter(object.parent)
      if player and player.Character then
          player.Character.Humanoid.Sit = true
          Boba.Services.QuestService:AdvanceQuest(player, "WaterslideRode", 1)
      end
  end)
  ```
* **Analysis:**
  - Infinite yield on line 1 waiting for `Boba`.
  - Touched event never connects because of the infinite yield.
  - References nonexistent legacy `QuestService:AdvanceQuest(player, "WaterslideRode", 1)`.
  - Property casing error: `object.parent` (lowercase p).
* **Recommendation:** `RECOMMEND_DISABLE`. Keep disabled. Note: `Workspace.Map.Part.Script` already provides sit functionality for the slide ramp without the broken legacy quest dependencies.

---

#### Script 6: `Workspace.Map.Model.Script` (Giant Rotating Boba Cup)
* **Status:** `Disabled = false` (**ACTIVE IN LIVE PLACE**)
* **Source:**
  ```luau
  local TweenService = game:GetService("TweenService")
  
  local modelCFrame = {}
  local defaultCFrame = script.Parent:GetPrimaryPartCFrame()
  
  for _,part in pairs(script.Parent:GetDescendants()) do
      if part:IsA("BasePart") or part:IsA("MeshPart") then
          modelCFrame[part] = part.CFrame
      end
  end
  
  local function resetPosition()
      for part,cfr in pairs(modelCFrame) do
          part.CFrame = cfr
      end
  end
  
  local CFrameAnim = Instance.new("CFrameValue")
  CFrameAnim.Changed:Connect(function()
      script.Parent:SetPrimaryPartCFrame(CFrameAnim.Value)
  end)
  CFrameAnim.Parent = game.ServerStorage
  
  while true do
      CFrameAnim.Value = defaultCFrame
  
      for i=1, 24000 do
          CFrameAnim.Value *= CFrame.Angles(0,.015,0)
          wait()
      end
      resetPosition()
  end
  ```
* **Analysis:**
  - **Performance / Architectural Defect:** Rotates the giant cup on the server in a tight `wait()` loop. Every frame, the server recalculates the primary part CFrame and replicates transform updates across the network to all connected clients.
  - Injects a `CFrameValue` into `game.ServerStorage` on server boot.
  - Deprecated APIs: `GetPrimaryPartCFrame`, `SetPrimaryPartCFrame` (superseded by `GetPivot` and `PivotTo`), and global `wait()`.
* **Recommendation:** `NEEDS_UPDATE`.
  - While it does not throw errors, running cosmetic visual rotations on the server wastes server budget and network replication bandwidth.
  - Move rotation logic to a client-side Controller (or Knit component) that rotates the model locally using `RunService.RenderStepped` for smooth 60+ FPS motion with zero network replication.

---

#### Script 7: `Workspace.Map.Part.Script` (Slide Ramp Sit Trigger)
* **Status:** `Disabled = false` (**ACTIVE IN LIVE PLACE**)
* **Source:**
  ```luau
  brick = script.Parent
  
  function OnTouched(part)
      local humanoid = part.Parent:FindFirstChild("Humanoid") 
      if (humanoid ~= nil) then
          humanoid.Sit = true
      end
  end
  
  script.Parent.Touched:connect(OnTouched)
  ```
* **Analysis:**
  - Functional and low-risk: sets `humanoid.Sit = true` when characters slide down the ramp.
  - Deprecated syntax: `:connect(...)` instead of `:Connect(...)`.
  - Global variable `brick` without `local`.
  - Lacks debounce: fires multiple times per touch as character parts collide.
* **Recommendation:** `SAFE_TO_KEEP`. It operates safely without throwing errors. Can be modernized during polish (add debounce, localize variables, use `:Connect`).

---

### 3.2. Discovered Legacy Scripts (Critical & Secondary)

#### Script 8a & 8b: `Workspace.Map.Model.Part.Script` (Fireworks Stand Purchases)
* **Status:** `Disabled = false` (**ACTIVE IN LIVE PLACE - CRITICAL RISK**)
* **Hierarchy:** `Workspace.Map.Model (Celebrity Launch Stand) -> Part -> ProximityPrompt -> Script`
* **Source (Huge Fireworks):**
  ```luau
  script.Parent.ProximityPrompt.Triggered:Connect(function(player)
      game.MarketplaceService:PromptProductPurchase(player,1120964689)
  end)
  ```
* **Source (Small Fireworks):**
  ```luau
  script.Parent.ProximityPrompt.Triggered:Connect(function(player)
      game.MarketplaceService:PromptProductPurchase(player,947356322)
  end)
  ```
* **Analysis:**
  - Prompts developer product `1120964689` (2,250 Robux) and `947356322` (500 Robux).
  - The revival codebase has **no receipt processing** for these developer product IDs.
  - Purchasing will deduct Robux from the player's account, but `ProcessReceipt` will not grant any items, potentially causing failed purchases and moderation complaints.
* **Recommendation:** `RECOMMEND_DISABLE` (**IMMEDIATE ACTION**). Set `Disabled = true` or delete the ProximityPrompts immediately.

---

#### Script 12 & 13: `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.*`
* **Status:** `Disabled = false` (12 Billboard scripts active in live place)
* **Pass IDs:**
  - `MopWhack`: `40973940`
  - `UnlimitedStock`: `43707849`
  - `Instant Brewing`: `12385760`
  - `VIP`: `12385781`
  - `Headless Head`: `14067340`
  - `Staff Intern`: `15243046`
  - `Rainbow Pack`: `12385796`
  - `Faster Walkspeed`: `12385742`
  - `Korblox`: `12385818`
  - `Fun Pass`: `12385799`
  - `Barista`: `6202153`
  - `Celebrity`: `6202153` (Duplicate ID)
* **Defect in `Celebrity.Script`:**
  ```luau
  --local Boba = require(game:GetService("ReplicatedStorage"):WaitForChild("Boba"))
  script.Parent.ClickDetector.MouseClick:Connect(function(player)
      local mainUIReplica = Boba:GetReplicaByClassToken("MainUIControlReplica")
      mainUIReplica:FireClient(player, "PromptCelebrityPurchase")
  end)
  ```
  Clicking the Celebrity billboard crashes with `attempt to index nil with 'GetReplicaByClassToken'`.
* **Recommendation:** `RECOMMEND_DISABLE`. The new React/Roact Shop UI replaces physical in-world advertisement billboards. Disabling these removes 12 redundant network calls to `GetProductInfo` on server startup and eliminates the Celebrity crash.

---

#### Script 14: `Workspace.OldScriptables.AdvertisementsFolder.Products.Donate!.Script`
* **Status:** `Disabled = false`
* **Source Excerpt:**
  ```luau
  local Products = {
      928273533, 55777641, 680670445, 680670692, 680670865,
      680671117, 680671325, 680671544, 680671832, 928275862,
      928276567, 1168137385,
  }
  ```
* **Analysis:**
  - Queries 12 developer products synchronously on server start without pcall wrappers.
  - Donation receipt processing is not currently wired in the server code.
* **Recommendation:** `RECOMMEND_DISABLE`. Disable to prevent unhandled donation receipts and startup HTTP throttling.

---

## 4. Risk Ratings and Actionable Recommendations

### Severity Classifications

1. **CRITICAL RISK (Requires Immediate Action Before Playtesting):**
   - `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script`: Set `Disabled = true`. Prevents server exception when players touch/interact with the teleporter.
   - `Workspace.Map.Model.Part.Script` (Both Fireworks scripts, IDs `1120964689` & `947356322`): Set `Disabled = true`. Prevents unhandled real-money Robux transactions.

2. **HIGH RISK (Obsolete In-World Monetization & Error Prone):**
   - `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.Celebrity.Script`: Set `Disabled = true`. Prevents crash when clicking the billboard.
   - `Workspace.OldScriptables.AdvertisementsFolder.Products.Donate!.Script`: Set `Disabled = true`.

3. **MEDIUM RISK (Performance & Cleanup):**
   - `Workspace.Map.Model.Script`: Refactor rotating Boba cup to client-side `RenderStepped` or Tween.
   - `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.*`: Disable billboard scripts; monetization should be handled via the modern Shop UI.

4. **LOW RISK / SAFE TO KEEP:**
   - `Workspace.Map.Part.Script` (Slide ramp sit): Safe to keep as-is.
   - `Workspace.Map.Model.Liquid.Script` (Boba cup liquid color): Safe to keep as-is.
   - `Workspace.Map.Model.Model.MeshPart.Script` (Particle toggle): Safe to keep as-is.
   - `Workspace.Map.Pika.Handle.Script` (Easter egg sound): Safe to keep as-is.
   - Already disabled scripts (`ElevatorScript`, `ZiplineHandler`, `FountainsFolder.Script`, `SlideSitPart.Script`): Keep `Disabled = true`.

---

## 5. M5 Pre-Release Cleanup Release Notes

When executing the M5 pre-release cleanup (via a Studio lease with Jack's approval), apply the following specific actions:

### In Studio:
1. **Disable Broken & Dangerous Scripts (`Disabled = true`):**
   - `Workspace.OldScriptables.CelebrityFolder.IslandTeleporter.Script`
   - `Workspace.Map.Model.Part.Script` (Huge Fireworks ProximityPrompt)
   - `Workspace.Map.Model.Part.Script` (Small Fireworks ProximityPrompt)
   - `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses.Celebrity.Script`
   - `Workspace.OldScriptables.AdvertisementsFolder.Products.Donate!.Script`
   - All 11 remaining scripts in `Workspace.OldScriptables.AdvertisementsFolder.Gamepasses`
2. **Verify Disabled Invariants:**
   - Confirm `ElevatorScript`, `ZiplineHandler`, `FountainsFolder.Script`, and both `SlideSitPart.Script` remain `Disabled = true`.
3. **Leave Untouched (`Disabled = false`):**
   - `Workspace.Map.Model.Script` (Rotating Boba cup — preserved until client-side component replacement is staged).
   - `Workspace.Map.Model.Liquid.Script`
   - `Workspace.Map.Model.Model.MeshPart.Script`
   - `Workspace.Map.Pika.Handle.Script`
   - `Workspace.Map.Part.Script`

### Verification Test Plan:
- In Studio Edit / Playtest mode:
  1. Trigger the Island Teleporter ProximityPrompt — verify no error logs appear in output.
  2. Approach the Fireworks stand — verify no prompt appears or prompt is inactive.
  3. Slide down the waterslide / ramp — verify character sits properly via `Workspace.Map.Part.Script`.
  4. Inspect the rotating Boba cup — verify it still spins smoothly.
  5. Check Developer Console (`F9`) on server boot — verify zero warnings regarding missing `ReplicatedStorage.Boba` or MarketplaceService HTTP failures.
