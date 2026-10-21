---
id: BOBA-PHONE
title: Boba Phone - faithful React port of the legacy Boba app, a Tool for every player, wired to OrderService:CreateOrder
priority: P1
role: Muse
worker_tier: external
release_gate: before
depends_on: [PHONE-RECON]
status: READY
source_commit: 62923cb
read_scope:
  - .review/agent-workflow/tasks/REVIVAL-001/BOBA-PHONE/brief.md
  - .review/agent-workflow/tasks/REVIVAL-001/PHONE-RECON/evidence.md
  - .review/agent-workflow/tasks/REVIVAL-001/PHONE-RECON/legacy-src/ (PhoneMenuController, ModifyDeviceSize, AppsHandler, Boba_Phone.LocalScript)
  - .review/agent-workflow/tasks/REVIVAL-001/PHONE-RECON/react-port/ (boba-app, shell-home, TOPFRAME; transcribed, NOT byte-exact)
  - src/shared/Ordering/Menu.luau (FoodTable, LaunchItems, LaunchChoices, IsLaunchItem)
  - src/shared/UI/Pages/MobileOrder/init.luau and src/shared/UI/Pages/Ordering/init.luau (order-item build, submit)
  - src/shared/UI/Components/ViewportModel.luau
  - src/shared/UI/Components/Core/Hud/TopBar.luau
  - src/client/Modules/AppDialogs.luau (DialogController:Toast), src/client/Modules/App/AppEntry.luau
  - src/server/Modules/OrderService.luau (Client:CreateOrder)
  - src/server/init.server.luau (service loading, PlayerAdded)
write_scope:
  - src/shared/UI/Pages/BobaPhone/ (new: init.luau, BuildOrderRequest.luau, view modules)
  - src/client/Modules/BobaPhoneController.luau (new)
  - src/server/Modules/BobaPhoneService.luau (new)
  - src/shared/UI/Components/Core/Hud/TopBar.luau (remove the register prompt effect and the locals it leaves unused, nothing else)
  - src/server/Tests/BobaPhone.spec.luau (new)
  - .review/agent-workflow/tasks/REVIVAL-001/BOBA-PHONE/ (summary.md, gate.txt)
invariants:
  - serve-path no-yield (M3-REM-B): do not touch CustomerService:_onServeTriggered, the RealOrderService payout, OrderService serve/deposit code, or FindServeTools; the phone only calls Client:CreateOrder
  - DEC-043 Q20=A: legacy look is ported faithfully (legacy fonts, colours, asset ids, sizes). Do NOT map to docs/STYLE.md tokens and do NOT invent new visuals
  - DEC-008: a missing place instance or asset is BLOCKED, never a substitute
  - economy is unchanged: no price, reward or real-player bonus edit; no level, XP or pool edit
  - never touch src/server/Scripts/ActivityScript.server.luau
  - the server is the authority: CreateOrder already validates; the client only sends {Category, Item, CustomInfo}
  - no Studio saves, no Play, no place edits; place content is Jack/Rigger (section 9)
acceptance:
  - see section 8 (code acceptance) and section 10 (Studio steps)
checks:
  - selene on every changed or new .luau file (no new findings; DEC-001 baseline)
  - stylua --check on the same files
  - rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/boba-phone-out/phone.rbxl (outside the repo)
  - TestEZ src/server/Tests/BobaPhone.spec.luau (section 6)
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BOBA-PHONE
forbidden: [WORKER-PRIMER 8, editing ActivityScript.server.luau, editing Menu.luau / OrderService.luau / Progression.luau / CustomerConfig.luau, STYLE.md restyle or new tokens, resurrecting ReplicatedStorage.Boba / ReplicaController phone / RemoteStorage, porting any app but Boba, level-locking menu items, push, merge, using any branch but agy-boba-phone]
---

Worker rules: `_meta/WORKER-PRIMER.md`, `docs/AI_AGENT_WORKFLOW.md`. Spec: `BOBA-PHONE/brief.md`. Decisions: DEC-040, DEC-043 (Jack, 2026-10-19). Jack, 2026-10-21: this is existing, proven legacy code; port it faithfully, Boba app only, the phone is a Tool given to every player, wired to the CURRENT gameplay code.

## 0. Worker setup (Muse)
- Work only in `C:/Users/jackc/AppData/Local/Temp/boba-phone`, branch `agy-boba-phone` (exists, cut from `uhweifh`). First run `git merge uhweifh` there to pick up the latest. Confirm `git branch --show-current` prints `agy-boba-phone`.
- Commit only in that worktree. Never push, never merge into anything else, never switch branches. Never edit `src/server/Scripts/ActivityScript.server.luau`.
- No Play, no Studio saves. Studio is read-only (inspect / script_read only) for the section 9 verification; record what you saw.
- Gates (save output to `BOBA-PHONE/gate.txt`): `selene <files>`, `stylua --check <files>`, `rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/boba-phone-out/phone.rbxl`. TestEZ: set `TESTS_ENABLED = true` in `src/server/Tests/RunTests.server.luau` locally in Studio, run, revert before committing; without Studio write `UNVERIFIED: TestEZ`.
- Deliverable: `BOBA-PHONE/summary.md` with the changed files, gate results, UNVERIFIED items, and at most 12 numbered Studio steps for Jack (section 10 is the source; trim to fit).

## 1. Decisions made (Architect; verified in src at 62923cb)
- D1 Menu source = `Shared.Ordering.Menu` (`require(ReplicatedStorage.Shared.Ordering.Menu)`, module name FoodService): `FoodTable[category] = { Icon, Color, LayoutOrder, Items }`, `Items[key] = { ItemName, ServeItem?, View?, Select?, RequiredSelection?, Options? }`. Same shape as the legacy FoodTable.
- D2 Show only launch items: copy `buildLaunchFoodTable()` and `launchOptions()` from `Pages/MobileOrder/init.luau` L10-48 (filter with `FoodService.IsLaunchItem(categoryKey, itemKey)`; filter RequiredSelection options by `FoodService.LaunchChoices[typeName]`). Current launch menu: Boba Teas (Custom Boba, Matcha Tea Boba), Coffees (Regular, Espresso, Decaf, Cappuccino, Americano, Cortado, Koa Coffee), Hot Cocoas (Classic, Caramel, Vanilla), Pastries (Fudge Brownie), Ice Creams (12), Macarons (8), Mochis (5), Others (Milk, Flavored Milk). Syrup flavours: Classic Milk Tea, Taro, Strawberry, Mango, Matcha, Brown Sugar, Chocolate, Passion Fruit. Tapioca: Normal, Strawberry, Mystic Burst, Banana Blast. `TopMenuSpecial` (Featured) is not in FoodTable and is not shown (the legacy phone did not show it; Matcha Tea Boba is already under Boba Teas).
- D3 Level locks: customers see NO level-locked items. `Progression.MIN_LEVEL_BY_ITEM` (Taro 2, Strawberry 2, Espresso 7, Mango 8, Matcha 8, ...) only gates the NPC order POOL (`CustomerConfig.ORDER_POOL`, `Rules.PickOrder`) and the Staff menu display (`Pages/Menu/Staff.luau`). Verified: neither `Pages/Ordering` nor `Pages/MobileOrder` references level, and `OrderService.Client:CreateOrder` checks only `isLaunchItem` and `buildOrderItem`. Every launch item, including Taro, Strawberry, Mango, Espresso and Matcha, is orderable by any player today. The phone matches the register pages: launch filter only, no level read, no lock icons, no Progression/profile require. Do not invent a gate (scope/economy is Jack's).
- D4 New drinks since the legacy phone need no phone code: Taro, Strawberry, Mango (Syrup Flavor choices), Espresso/Decaf/Cappuccino/Americano/Cortado/Koa (Coffees), Matcha Tea Boba, Hot Cocoa Classic/Caramel/Vanilla, Ice Creams, Macarons, Mochis, Others all arrive through `FoodTable` + `LaunchItems`. Render from data only; never hard-code names.
- D5 Order-item build = copy `MobileOrder` onSelectItem / onAddItem / onSubmitOrder (L168-L281) exactly:
  - on item tap: `info[selectType] = options[1]` for each `item.Select` (Size defaults to its first value, `Small`); `info[optionType] = defaultValue` for each `item.Options` (Coffees: `Iced=false`, `Sugar=false`; Teas: `Iced`); then queue one required-selection step per `item.RequiredSelection` group (Syrup Flavor, Tapioca Flavor; options filtered via `launchOptions`); each pick sets `info[groupName] = optionKey`.
  - cart entry `{ Category, Item, DefaultInfo = itemData, CustomInfo = info }`; cap `MAX_ORDER_ITEMS = 3` (the legacy cap, same as both register pages; the server allows 1-4).
  - request = `{ { Category = e.Category, Item = e.Item, CustomInfo = e.CustomInfo }, ... }`. DefaultInfo is never sent (the server rebuilds from its Menu; see "a MobileOrder order item resolves, and its DefaultInfo is ignored" in `OrderSpec.spec.luau`).
  - Put this pure mapping in `BuildOrderRequest.luau` so it is specable (section 4).
- D6 Submit: `Knit.GetService("OrderService"):CreateOrder(Players.LocalPlayer.UserId, request):expect()` inside `pcall` in `task.spawn`, guarded by an `isSubmitting` ref. Result type `{ Success: boolean, Message: string? }`. Server limits (`OrderService.Client:CreateOrder`): customerId must equal the caller (`You can only place orders for yourself.`); 5 s debounce per player (`Please wait before placing another order.`); 1 to 4 items (`Orders need 1 to 4 items.`); every item must pass `isLaunchItem` (`That item isn't available right now.`); malformed item = `Invalid order.`; one open order per player (`You already have an order in progress.`); success = `{ Success = true, Message = "Order placed." }`. Do not duplicate these checks on the client beyond the 3-item cap and the empty-cart guard.
- D7 Result feedback (DEC-043 Q21=A): `Knit.GetController("DialogController"):Toast(text)` (`AppDialogs.luau` L242; `SmallNotification.Push({ Text = text })`). Success: `message or "Order sent."`, clear the cart, return to the Menu tab. Failure (including pcall failure): `message or "Unable to submit order."`, keep the cart. Use `:Toast`, NOT `:Notify` (SmallNotification ignores Title and Description). Wrap the Toast in `pcall` (precedent `KitchenController` L101). No order-status screen.
- D8 Hide the unwired Home and History tab buttons (already `Visible = false` in the legacy dump). The phone opens straight on the Order page, Menu sub-tab. Keep the Menu / My Order toggle and the Place Order button.
- D9 Registers: remove the "Use Ordering System" prompt from `TopBar.luau`: the `if RunService:IsRunning() then React.useEffect(...)` block (about L58-L101) that creates ProximityPrompts on `workspace["Ordering System"].Computers`, plus `waitForComputers`, `ORDERING_SYSTEM_TIMEOUT_SECONDS`, `CLOCKED_IN_ATTRIBUTE` and any `Players` / `RunService` / `WorldPath` require that Selene then reports unused. `Pages.Ordering` and `OrderController.OpenOrderingTablet` stay: the barista tablet (Take Order, `CustomerService.Client:SubmitNpcOrder`) still uses `Pages/Ordering` with `npcOrderData`. Ship the removal in the same commit as the phone. `Pages/MobileOrder` stays unmounted and untouched (reference only).
- D10 Tool grant: new Knit service `src/server/Modules/BobaPhoneService.luau` (auto-loaded by `Knit.AddServicesDeep`; `PlayerAdded(player)` is called by `server/init.server.luau`). On PlayerAdded: `ReplicatedStorage:WaitForChild("ToolsStorage", 10)` then `["Boba Phone"]`; if missing, `warn` once and return (BLOCKED, no substitute). Clone it, destroy every descendant `LocalScript` (the legacy toggle; the React controller replaces it), `SetAttribute("BuiltBy", "Muse")`, `SetAttribute("BobaPhone", true)`, and parent one clone into `player.StarterGear` (survives respawn) and, if `player.Backpack` has no tool of that name, another into `player.Backpack` (current life). Never grant twice (check Backpack, Character, StarterGear). No Rojo place edit; no remote.
- D11 Client: `src/client/Modules/BobaPhoneController.luau` (Knit controller, auto-loaded by `AddControllersDeep`). `KnitStart`: create a `ScreenGui` named `BobaPhoneReact` (`ResetOnSpawn=false`, `IgnoreGuiInset=true`, `ZIndexBehavior=Sibling`, `DisplayOrder` just above AppEntry's gui), `ReactRoblox.createRoot`, render `Pages/BobaPhone` with an `Open` boolean in state. Watch the local Character and Backpack for a Tool with attribute `BobaPhone == true` (`Equipped` / `Unequipped`, reconnect on `CharacterAdded`); Equipped = open, Unequipped or character removal = close. The `BobaPhoneReact` name cannot collide with a legacy `PlayerGui.BobaPhone` (section 9).
- D12 Mount: NOT through `App.luau` / `SetCurrentPage` (that is the modal Page host with a one-page swap; the phone is an equip-driven overlay that must coexist with the HUD and the Ordering tablet). `App.luau` is untouched.
- D13 Item card pictures: use the existing `UI.Components.ViewportModel` (props `Model`, `Size`, `ElevationAngle`, `FieldOfView`, `ModelRotation`) with `itemData.View.Model` (set in Menu from `ReplicatedStorage.SelectorModels` via `CUP_MODELS:FindFirstChild(...)` and `Models["Pastry"]:FindFirstChild(...)`). This replaces the legacy ViewportProvider; do not build a new one. When `View.Model` is nil, render the card with the item name only (legacy cards also show the name) and report which items. `View.ModelDistance` / `View.Direction` are ignored (ViewportModel frames by bounding box); note it in summary.md.
- D14 Look (faithful, DEC-043 Q20=A): build the phone body, notch, Boba app chrome, category rows, item cards, My Order rows, ItemOptions and SelectList popups from the legacy tree. Source of truth is the Studio modules `StarterGui.UIArchive.OldUI.BobaPhone.Frame.__REACT_SCREEN` (Boba app = lines 549-1380) and `__REACT_TOPFRAME`, read with `script_read` (the `react-port/` copies are agent transcriptions, not byte-exact). The phone body Frame (black rounded body, `AnchorPoint .5,1`, `Size {0.3,0},{1,-20}`, `Position {0.5,0},{1,-70}`, `UIAspectRatioConstraint`, `UISizeConstraint`) was not chunked: read it from the live `StarterGui.UIArchive.OldUI.BobaPhone.Frame` properties. Keep the legacy image ids (PHONE-RECON/evidence.md section 6 and the dump), fonts (GothamSSm, FredokaOne), colours (accent 255,104,5; greys 48/128/204) and offset/scale sizing as dumped. Translate the dump into real React: `local c = React.createElement`, one component per section, templates flattened into data-driven lists, `Visible=false` template nodes dropped, script stubs dropped, `Font.new` kept. Drop the Home screen, icon grid, CloseApps, AppsHandler slide and every retired app (Web, Chat, Jokes, Word Of The Day, Subs, Games, Gifts, Event).
- D15 `ModifyDeviceSize` (touch and AbsoluteSize.Y < 500: phone to right/bottom, size `(0.5,0,1,26)`) is ported as a check on `UserInputService.TouchEnabled` and the ScreenGui `AbsoluteSize` (via a ref), applied to the body Frame props.
- D16 Legacy bugs are NOT ported: undeclared globals (MenuHandler), the `while wait(3600)` and the wrong `GetPropertyChangedSignal` call (TimeHandler). There is no clock; the hard-coded greeting and date go with the Home screen.

## 2. Verified current-code facts
- Menu: `src/shared/Ordering/Menu.luau` `FoodService.FoodTable`, `LaunchItems`, `LaunchChoices`, `IsLaunchItem(category, item, customInfo?)` (about L703-L790).
- Options and customizations in OrderSpec: `Select` (Size Small/Medium/Large; Mug for cocoas), `Options` (Iced / Sugar booleans), `RequiredSelection` (Syrup Flavor, Tapioca Flavor). `OrderSpec.FromOrderItem` builds the spec server-side from `{Category, Item, CustomInfo}`; wrong or missing choices are rejected as `Invalid order.`. So the phone must always send the Select and Options defaults plus both RequiredSelection picks; Add Item is only reachable after the required popups (as in legacy and MobileOrder).
- Tablet ordering and Dedicated staff assignment (`CustomerConfig.ASSIGNMENT_MODE = "Dedicated"`; `CustomerService.OpenOrderingTablet` -> `OrderController.OpenOrderingRequested` -> `Pages/Ordering` with `npcOrderData`): this is a BARISTA taking an NPC order, submitted through `CustomerService:SubmitNpcOrder`. It is a separate path from a real player's own order. The phone never calls `SubmitNpcOrder` or the tablet and needs no staff or NPC logic. The player's phone order is a normal `OrderService` order that baristas pick up through the existing queue.
- Clock-in: `ShiftService` attribute `ClockedIn` (default true). DEC-046 hid the register prompt for clocked-in players. The phone and `ClockedIn` are mutually exclusive (R3, decided by Jack 2026-10-21).
- Toast: D7.
- Code that can see a held or carried phone (R1): `FindFirstChildWhichIsA("Tool")` on the character in `KitchenService/Actions/*`, `KitchenService/InteractionRunner.luau`, `KitchenService/PourMoments.luau`, `client/Modules/KitchenController.luau` L110, `UI/Components/Core/Hud/OrderTicket.luau` L322; `OrderService.collectTools` (character + Backpack) feeding `FindServeTools`.
- The Ordering page is mounted only by `TopBar` (register prompt) and `OrderController` signals through `App.luau`; `Pages/MobileOrder` is referenced only by its story and `OrderSpec.spec.luau`.

## 3. Exact strings
- Toast on success: the server `Message` (`Order placed.`), else `Order sent.`
- Toast on failure: the server `Message`, else `Unable to submit order.`
- Preview (`RunService:IsRunning()` false): do not call the server; show `Preview mode: order not submitted.` inline in the My Order footer (as `MobileOrder`); no Toast.
- All other labels are the legacy strings from the dump (category titles come from `FoodTable` keys; "Add Item", "Place Order", "Menu", "My Order" as dumped).
- Tool name `Boba Phone`; gui name `BobaPhoneReact`; attribute `BobaPhone = true`; `BuiltBy = "Muse"`.

## 4. Signatures
- `BuildOrderRequest.MAX_ITEMS = 3`
- `BuildOrderRequest.launchFoodTable(menu): FoodTable` (D2 filter, pure, takes the Menu module so specs can pass it)
- `BuildOrderRequest.defaultInfoFor(itemData: { [string]: any }): { [string]: any }`
- `BuildOrderRequest.cartEntry(category: string, itemKey: string, itemData: { [string]: any }, info: { [string]: any }): CartEntry`
- `BuildOrderRequest.appendCapped(cart: { CartEntry }, entry: CartEntry): { CartEntry }` (returns a new cart; no-op at 3)
- `BuildOrderRequest.toRequest(cart: { CartEntry }): { { Category: string, Item: string, CustomInfo: { [string]: any } } }`
- `Pages/BobaPhone/init.luau`: `return function(props: { Open: boolean, OnClose: (() -> ())? })`
- `BobaPhoneService:PlayerAdded(player: Player)`; pure helper `BobaPhoneService.prepareClone(tool: Tool): Tool`. No Client table, no remote.
- `BobaPhoneController:KnitStart()`
- No new remote, no profile field, no server attribute beyond `BobaPhone` on the Tool.

## 5. Allowed deviations
- Reuse `ViewportModel` for item pictures (D13) even where legacy cards looked slightly different.
- Hard-coded legacy text (greeting, date) is dropped, not kept.
- If a legacy asset id fails to load in this experience, report it; do not swap art.

## 6. Spec cases (`src/server/Tests/BobaPhone.spec.luau`; pure)
`Menu.luau` calls `game.ReplicatedStorage:WaitForChild("SelectorModels")` at require time; follow how `OrderSpec.spec.luau` requires it.
- `launchFoodTable` keeps only `IsLaunchItem` items: no `Smoothies` or `Teas` category; `Pastries` has only `Fudge Brownie`; `Coffees` has `Espresso`.
- Required-choice options for `Custom Boba` Syrup Flavor, after the launch filter, equal `LaunchChoices["Syrup Flavor"]` as a set.
- `defaultInfoFor` for `Coffees/Espresso` = `{ Size = "Small", Iced = false, Sugar = false }`; for `Custom Boba` = `{ Size = "Small" }`.
- `toRequest` drops `DefaultInfo` and keeps `Category`, `Item`, `CustomInfo`.
- Round trip: a request built from `Custom Boba` (`Syrup Flavor = "Taro"`, `Tapioca Flavor = "Normal"`, `Size = "Medium"`), `Coffees/Espresso` defaults, and `Pastries/Fudge Brownie` each pass `OrderSpec.FromOrderItem` with no reason.
- Taro, Espresso and Mango (levels 2, 7, 8) pass `IsLaunchItem` and are present in `launchFoodTable` (documents D3: no level locks).
- `appendCapped` leaves 3 entries after 4 appends.
- `prepareClone` destroys all LocalScripts, sets `BobaPhone = true` and `BuiltBy = "Muse"`.
- The Tool grant itself is a Studio check.

## 7. UI spec
- Everything is the legacy look (D14). No STYLE.md tokens apply and none may be introduced. Where the dump and a current system conflict, the current system wins on behaviour, legacy wins on appearance.
- Behaviour: Menu tab = category rows (ordered by `LayoutOrder`, coloured by `Color`) each with a horizontal scroller of item cards (picture and name). Tap a card: ItemOptions popup. Size is a segmented picker; each RequiredSelection group opens the SelectList (coloured choice buttons using the choice `Color`); Options are toggles. Add Item appends and switches to My Order. My Order rows show the name with the Size prefix, `Type: value` lines for required picks, `+ X` / `- NO X` for toggled options, and an X to remove. Place Order submits (D6, D7) and is disabled while submitting and with an empty cart.
- Open/close: Tool Equipped shows the phone, Unequipped hides it. Closing resets popup state but keeps the cart (legacy kept it until placed).
- The phone is independent of the Ordering tablet page; if they overlap, report it.

## 8. Code acceptance
- `Pages/BobaPhone` renders the Boba app only: no Home screen, no other app, no Home/History tabs.
- The request built from the UI equals D5; `CreateOrder` is the only server call; the result is shown with `:Toast` (D7).
- The menu is data-driven from `FoodTable` filtered by `IsLaunchItem`; no level reads.
- `TopBar.luau` creates no "Use Ordering System" prompt; `Pages.Ordering` and the barista tablet are untouched; Selene has no new findings in TopBar.
- `BobaPhoneService` gives each player one `Boba Phone` Tool (no LocalScript inside, `BobaPhone` attribute); a missing `ToolsStorage."Boba Phone"` warns once and does not error.
- Gates pass with no new findings in changed files; specs written; `summary.md` lists UNVERIFIED items.

## 9. Place-file instances this depends on (verify read-only; BLOCKED if absent, DEC-008)
| Path | Needed for | Check |
|---|---|---|
| `ReplicatedStorage.ToolsStorage["Boba Phone"]` (Tool, `RequiresHandle=false`, one LocalScript child) | the grant (D10) | exists; record its children; the clone's LocalScript is destroyed in code |
| `ReplicatedStorage.SelectorModels` (children `Cup`, `Pastry`, others) | the `Menu.luau` require and item pictures (`View.Model`) | exists; `Cup` has `Boba` and `Medium Cup`; `Pastry` has `Fudge Brownie` etc. List any launch item whose `View.Model` is nil |
| `StarterGui.UIArchive.OldUI.BobaPhone` (ScreenGui) | art and layout source only | `Frame`, `Frame.Screen.Apps.Boba`, `Frame.__REACT_SCREEN`, `Frame.__REACT_TOPFRAME` present; read, do not edit |
| `Players.<you>.PlayerGui.BobaPhone` at runtime | none; a legacy copy exists only if UIArchive is cloned into PlayerGui | Studio step 2: if it exists and is Enabled it overlaps the new phone; report, do not delete (needs a Rigger lease) |
| `workspace["Ordering System"].Computers` | formerly the register prompts | after D9 nothing creates prompts on it; leave the instances |
Not needed and not to be resurrected: `ReplicatedStorage.Boba`, `RemoteStorage`, `ReplicatedValues`, `ViewportProvider`, `PhoneServiceReplica`, `PhoneEvent`.

## 10. Studio checks (Jack, one run; the worker's summary.md carries at most 12)
1. Edit mode: confirm `ReplicatedStorage.ToolsStorage["Boba Phone"]` exists and `SelectorModels` has `Cup` and `Pastry`.
2. Play solo: `Players.<you>.PlayerGui` shows `BobaPhoneReact` and either no `BobaPhone` or one that is not Enabled.
3. The Backpack shows one `Boba Phone` with no LocalScript. Respawn: still exactly one.
4. Equip it: the phone opens (legacy position), Order page, no Home or History tabs.
5. The menu lists category rows with item cards; Boba Teas has Custom Boba and Matcha Tea Boba; Coffees has Espresso; no Smoothies or Teas rows. Item pictures render (note any blank).
6. Tap Custom Boba: pick Size, Syrup Flavor (Taro and Mango visible), Tapioca Flavor; Add Item adds a My Order row with those lines.
7. Add Espresso with Iced toggled: the row shows `+ Iced`. A 4th item is ignored (cap 3).
8. Place Order with items: toast `Order placed.`, cart clears; the order shows in the staff queue and status screens as a normal order.
9. Place Order again within 5 s or while the order is open: the toast shows the server refusal, the cart is kept.
10. Unequip: the phone hides. Equip again: it reopens.
11. At a register: no "Use Ordering System" prompt on any computer; Take Order on an NPC still opens the barista tablet.
12. Mobile emulator (small phone): the phone moves right/bottom (ModifyDeviceSize) and taps work.

## 11. Open items and risks
- R1 (verify, do not fix): a held `Boba Phone` is a Tool, so the `FindFirstChildWhichIsA("Tool")` kitchen and ticket helpers (section 2) and `OrderService.collectTools` / `FindServeTools` can see it. `FindServeTools` grades by tool attributes and the phone has none. Read `OrderSpec.PickTools` and state in summary.md whether an attribute-less extra tool can change a grade or the tools picked, and which kitchen actions misbehave while the phone is equipped (GiveTool, SetToolAttributes, InteractionRunner, PourMoments, OrderTicket). These are kitchen and serve-path files: do not edit them. If a fix is needed, report it as PENDING JACK with the exact guard (`tool:GetAttribute("BobaPhone") ~= true`).
- R2 Item pictures: a nil `View.Model` gives a text-only card (D13). The models are place content.
- R3 DECIDED (Jack 2026-10-21): being clocked in and having the Boba Phone are mutually exclusive. BobaPhoneService listens to the `ClockedIn` attribute:
  - On clock-in, unequip and remove the phone from Backpack and StarterGear.
  - On clock-out, give it back.
  - Server `CreateOrder` from a clocked-in player is refused with a toast reason, so it can't be bypassed.
  - The phone UI closes if it's open at clock-in.
  - Check `ClockedIn`'s default (section 2 says default true). Players must start with the phone unless they are actually clocked in. If the default would keep it from everyone, report it instead of changing ShiftService defaults.
  - This also resolves R1 for kitchen work, since staff can't hold the phone. Still note R1's findings in summary.md.
- R4 Legacy image ids may be unavailable to this experience; report load failures, do not substitute.
- R5 `__REACT_SCREEN` is 3,444 lines; only lines 549-1380 and the shell/body are in scope.
- R6 TestEZ and Play belong to Jack/Studio (DEC-019); mark UNVERIFIED if not run.

## Summary
- Boba-app-only React phone ported faithfully from the legacy tree and the chunked dump; data from `Menu.FoodTable` filtered by `IsLaunchItem`; no level locks (matches the register pages and `CreateOrder`).
- The request is `{Category, Item, CustomInfo}` x1-3, sent via `OrderService:CreateOrder`; the result is shown with `DialogController:Toast`.
- `BobaPhoneService` clones `ToolsStorage."Boba Phone"` (LocalScript destroyed) to every player; `BobaPhoneController` opens a separate `BobaPhoneReact` overlay on Equip.
- The register "Use Ordering System" prompt is removed from `TopBar.luau`; tablet ordering and Dedicated assignment are untouched.
- Main risk: an equipped Tool is visible to kitchen and serve `FindFirstChildWhichIsA("Tool")` code (R1).
