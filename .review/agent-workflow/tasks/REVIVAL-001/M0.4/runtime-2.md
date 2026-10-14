# REVIVAL-001-M0.4 run 2 - Gauge runtime QA

- Task: REVIVAL-001-M0.4 (run 2). Date 2026-10-14. Studio `0bec4a01-246f-4fcf-b1b5-d37cfaf45e80` ("jacks project", place 89999123284040), Rojo live sync, 1 player (bongusbingis, uid 176353970).
- HEAD `92f61447ecd8ebb898fefb841261fabeb46b51cd` plus uncommitted tree (branch uhweifh). Hashes at end of run:
```
c81bef93ad1388a7b6cfcb58a415f6a183b553b1  src/server/Modules/OrderService.luau
981472316a26fbe4a3ec1044072ec41d123ed992  src/server/Modules/KitchenService/init.luau
3b2564de81b6e255c86897a760fbdc3636b04891  src/server/Modules/ShiftService.luau
16c5076d0e777c93eb293cd1f5da684ef7e6f2a2  src/server/Scripts/ProcessReceipt.server.luau
```
- TESTS_ENABLED = false (RunTests.server.luau:7, unchanged). No repo files edited. Place not saved/published; Studio left in Edit mode.
- Play-session-only test setup (not persisted): server set kitchen ProximityPrompt.MaxActivationDistance=9.5 and toggled Enabled so only the target station responds; character HumanoidRootPart anchored and teleported next to stations. Real inputs used: HUD click on the Clock button, keyboard E hold on prompts, mouse clicks on dialogs, and the real CreateOrder RemoteFunction (OrderService.RF.CreateOrder) from the client. Tool: `ProximityPrompt:InputHoldBegin` from client did NOT trigger server prompts; the E key did.
- Note: the player holds rank 24 in the creator group, so "no group rank" is not literally reproducible. No kitchen/order path reads rank (grep: only RankUtil.luau and PlayerSetup IsInGroupAsync), so the paths exercised are the rank-less ones.

| # | Scenario | Result |
|---|----------|--------|
| 1 | Zero-error boot | PASS (0 game errors) |
| 2 | Clock-in gate | PASS |
| 3 | Boba / coffee / brownie | FAIL for boba (16 of 19 syrups); Regular coffee PASS; Fudge Brownie PASS |
| 4 | Order round trip | PASS |
| 5 | 2 players | UNVERIFIED |

## 1. Boot: PASS
Server+client Knit both start ("[Client] Knit started successfully.", "[Server] Knit started successfully."), HUD renders (capture M04_Run2_Boot: Shop/Menu/Inventory, clock, Clock Out, Staff Guide, points, cash). Run-1 P0 (SoundService.SFX.UI missing) is gone. Console: console-run2-boot.txt. Zero errors. Warnings only:
- 5 asset-permission lines + 10 "Failed to load sound" (known, Jack's).
- [SpillController] FallingAnimation missing; [SpillService] Spills disabled (4 authored paths missing); [Settings] SoundService.Music / SoundService.SFX "missing or not a SoundGroup" (x2; place content); BadgeService/profilestore info.
- Observed cosmetic: overhead nametag reads "Customer" while the player is on team Baristas and clocked in (capture M04_Run2_Boot, M04_Run2_ClockedIn). Not investigated (likely place-authored BillboardGui).

## 2. Clock-in gate: PASS
- Click the HUD "Clock Out" button: ClockedIn=false, Team Customers, label flips to "Clock In".
- While clocked out: E on the Cup station. A server-side Triggered hook confirmed the prompt fired ("Cup by bongusbingis"), yet no size dialog opened and no tool was given. Gate holds (KitchenService init.luau _isClockedIn).
- Click "Clock In": ClockedIn=true, Team Baristas; the same E opens the Cup "Choose a size" dialog (capture M04_Run2_CupSize). Raw RF toggles were verified in run 1.
- Observation: prompts stay visible/enabled while clocked out and refuse silently (no toast). UX gap, not a fault.

## 3. Kitchen: FAIL (boba)
Method: station-by-station, real E hold, dialogs clicked. Console lines in console-run2-play.txt.
- **FAIL: Tapioca refuses the tool after a non-tea syrup.** Repro: Clear Cup (Small) -> "Small Clear Cup"; Milk -> "Small Clear Cup + Milk"; Taro Syrup -> tool renamed "Milk + Taro Syrup" (cup size text lost); Normal Tapioca -> refused, tool stays "Milk + Taro Syrup". Console: `Milk + Taro Syrup  Milk` and `Milk + Taro Syrup Tea` (debug print of toolName, term; both terms fail). Cause: Recipes.luau:329 `{ "# Milk|#Tea" }` needs " Milk" (leading space) or "Tea" in the name, while the syrup step (Recipes.luau:318) names it `Milk + {name} Syrup`. Only syrups whose name contains " Milk" or "Tea" pass: Classic Milk Tea, Thai Milk Tea, Green Tea. The other 16 syrups (Taro, Mango, Coconut, Matcha, Strawberry, ...) cannot get tapioca = no boba. Answer to the key question: NO for most syrups.
- **FAIL (data): the Boba rename mangles the name.** Repro: Clear Cup (Medium) -> Milk -> Classic Milk Tea Syrup ("Milk + Classic Milk Tea Syrup") -> Normal Tapioca accepted -> tool becomes `Boba + Classic Boba Tea Syrup` (Recipes.luau:345 `old:gsub("Milk","Boba")` replaces every "Milk"; it also returns a 2nd value count). Quest code in OrderService._handlePickUp compares `CurrentItem == "[Syrup] Boba"`, which does not match these names (not exercised here; flagged by reading only).
- Minor: ToolNameValidityCheck.luau:21 leaves a debug `print` on every "#" term (noisy console).
- Regular coffee PASS: Cup (Medium) -> "Medium Cup"; Coffee Machine (7 s hold) -> PromptSelection (M04_Run2_CoffeeSelect) -> Regular -> tool "Regular".
- Fudge Brownie PASS: Food Display -> picker (M04_Run2_FoodDisplay) -> tool "Fudge Brownie".
- Engine warnings "Part X is not parented to the Workspace or a WorldModel. GetConnectedParts ..." repeat on tool steps (cup parts: Cup, Camera, Handle, BobaBalls, TouchThing, Liquid, CoffeeLid, Straw, Bottom, Slice; coffee: CoffeeCup, CoffeeHolder). Likely from tool cloning/welding of un-parented tools (GiveTool.luau AutoWeld); harmless but noisy. Not triaged.
- Reach observation: with default PROMPT_DISTANCE 6 the character standing at the counter was 6.06 to 6.29 studs from the Cup prompt part (bounding-box centre) in 3 attempts, i.e. just outside the prompt range. Not conclusive (my standing spots were guesses; character_navigation also stalled), but worth a human walk-through of the kitchen.

## 4. Order round trip: PASS
Via OrderService.RF.CreateOrder (same call the Ordering UI makes, Ordering/init.luau:275):
- Malformed (all rejected, `ok=true`, no server error): no args, string customerId, nil/string items, empty, 5 items ("Orders need 1 to 4 items."), non-table item, unknown category/item, bad Size, extra CustomInfo key, non-table CustomInfo, non-boolean option, nested-table Category/Item: "Invalid order." Matching server warns "[OrderService] Rejected order ...". NaN customerId and another user's id: "You can only place orders for yourself."
- Valid order Coffees/Regular {Size=Medium}: "Order placed." Duplicate (immediate, and after the 5 s debounce): "You already have an order in progress." (debounce msg "Please wait ..." seen once.)
- Note: a sparse array {[1]=item,[3]=item} is accepted as a 1-item order (only the array part is read; harmless).
- Claim: E at the "Pending Orders Screen" -> "Order Ticket: Medium Regular" shown (M04_Run2_Claimed). Deposit: E at a Pick Up node -> "Select Item 1 of 1" dialog listing every held tool (M04_Run2_DepositDialog); chose Regular: node owner=176353970, prompt "bongusbingis's Order / Pick Up Order", ServerStorage.OrderPickUp.Order_176353970 holds Regular. Pickup: E again -> owner reset to 0, folder destroyed, Regular back in the Backpack. A second valid 2-item order ("Order placed.") afterwards works.
- UNVERIFIED: "order already claimed by another user" (needs a 2nd barista); with 1 player, a 2nd claim by the same player was not exercised.

## 5. Two players: UNVERIFIED
The Roblox Studio MCP exposes one Server and one Client datamodel; no local multi-client server start is available through it (Test tab > Clients and Servers must be launched by hand). Needs Jack or a manual run: two baristas claiming, queue (_joinQueue), another player picking up someone else's order, ClockedIn per player.

## Captures
M04_Run2_Boot, M04_Run2_ClockedIn, M04_Run2_CupSize, M04_Run2_ClearCup, M04_Run2_CoffeeSelect, M04_Run2_FoodDisplay, M04_Run2_Claimed, M04_Run2_DepositDialog (screen_capture ids; files under ~/.claude/projects/-Users-jackcrowell-Desktop-boba-cafe/.../tool-results/).

## Files
console-run2-boot.txt, console-run2-play.txt

- ProcessReceipt.server.luau hash at start of run was 85103614c5c382d7010358f1fa8a904514171e07; it changed during the run (Mason M0.6 edit, expected). Runtime results do not exercise it.
