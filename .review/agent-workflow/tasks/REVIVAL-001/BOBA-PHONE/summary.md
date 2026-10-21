# BOBA-PHONE summary (worker: Muse, worktree `agy-boba-phone` @ e1812f1 + merge `uhweifh`)

Faithful React port of the legacy Boba ordering app as an equip-driven Tool for every
player, wired to `OrderService:CreateOrder`. Boba app only; Home/History tabs dropped;
register "Use Ordering System" prompt removed in the same change.

## Changed files
- `src/shared/UI/Pages/BobaPhone/BuildOrderRequest.luau` (new): pure cart mapping (D2/D5).
  `MAX_ITEMS = 3`, `launchFoodTable(menu)`, `launchOptions(menu, typeName, options)`,
  `defaultInfoFor(itemData)`, `requiredQueueFor(menu, itemData)`, `cartEntry(...)`,
  `appendCapped(cart, entry)`, `toRequest(cart)`. Mirrors MobileOrder exactly.
- `src/shared/UI/Pages/BobaPhone/init.luau` (new): `props: { Open: boolean, OnClose: (() -> ())? }`.
  Legacy look from `__REACT_SCREEN` lines 549-1380 + `__REACT_TOPFRAME` (GothamSSm/FredokaOne,
  accent 255,104,5, tab green 96,202,94, asset ids 8267206830/5150079965/5017723314/5150445362/
  4983877983/1912796145 kept as dumped). Menu tab = category rows by LayoutOrder with
  horizontal item-card scrollers (ViewportModel picture + name; name-only card when
  `View.Model` is nil). ItemOptions popup (Size segmented picker, RequiredSelection rows
  opening the SelectList with choice `Color` buttons, Options toggles), Add Item gated until
  all required picks are set, My Order rows (`Size`-prefixed name, `Type: value` lines,
  `+ X` / `- NO X`, X remove), Place Order (disabled while submitting / empty cart).
  Submit = `CreateOrder(LocalPlayer.UserId, request):expect()` in `task.spawn`+`pcall` with
  `isSubmitting` ref; result via `DialogController:Toast` in `pcall` (D7). Preview mode shows
  `Preview mode: order not submitted.` inline, no server call. `ModifyDeviceSize` ported
  (touch + ScreenGui AbsoluteSize.Y < 500 moves the body right/bottom). No level reads.
- `src/client/Modules/BobaPhoneController.luau` (new): Knit controller (auto-loaded).
  Own `BobaPhoneReact` ScreenGui (`ResetOnSpawn=false`, `IgnoreGuiInset=true`,
  `ZIndexBehavior=Sibling`, `DisplayOrder=1`, just above AppEntry). Watches Character for a
  Tool with `BobaPhone == true` (Equipped=open, Unequipped/removal/CharacterRemoving=close;
  reconnects on CharacterAdded). NOT through App/SetCurrentPage; App.luau untouched.
- `src/server/Modules/BobaPhoneService.luau` (new): Knit service (auto-loaded).
  `PlayerAdded` grants one `Boba Phone` clone from `ReplicatedStorage.ToolsStorage`
  into StarterGear + Backpack (never twice; checks Backpack/Character/StarterGear).
  `prepareClone` destroys all descendant LocalScripts, sets `BobaPhone=true`,
  `BuiltBy="Muse"`. Missing ToolsStorage/tool warns once and returns (no substitute).
  R3: listens to the `ClockedIn` attribute; clock-in removes the phone everywhere,
  clock-out re-grants. Client also refuses submit while clocked in
  (`Clock out to order with the phone.` + toast). DEFAULT_CLOCKED_IN=true stands:
  new baristas get the grant removed as soon as ShiftService sets the attribute;
  clocking out grants it back. No OrderService/Menu/Progression/CustomerConfig/
  ActivityScript edits; no new remote, profile field, or server attribute.
- `src/shared/UI/Components/Core/Hud/TopBar.luau` (D9): removed the register-prompt
  `useEffect`, `waitForComputers`, `ORDERING_SYSTEM_TIMEOUT_SECONDS`,
  `CLOCKED_IN_ATTRIBUTE`, and the now-unused `RunService`/`Players`/`WorldPath`
  requires. Nothing else touched; `Pages.Ordering` + barista tablet untouched.
- `src/server/Tests/BobaPhone.spec.luau` (new): section-6 cases (launch filter, D3 levels,
  defaults, cap, request shape, FromOrderItem round trip, prepareClone). Written, not run.
- `.review/agent-workflow/tasks/REVIVAL-001/BOBA-PHONE/gate.txt`: raw gate output.

## Gate results (all PASS, `agy-boba-phone`)
- selene: 0 errors, 0 warnings on all 6 new/changed files; HEAD TopBar baseline 0/0/0,
  so no new findings (DEC-001).
- stylua --check: PASS on all 6 (TopBar normalized LF; repo norm).
- `rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/boba-phone-out/phone.rbxl`:
  PASS (`Built project to phone.rbxl`, 1,519,196 bytes). Note: the worktree `Packages` /
  `ServerPackages` junctions were recreated (same targets) after rojo 7.7.0 refused the
  stale ones as untrusted mount points (os error 448); gitignored, uncommitted.
- TestEZ: UNVERIFIED (worker did not run Play/TestEZ per packet; spec written for Jack).

## UNVERIFIED / needs Studio (Jack)
- TestEZ `BobaPhone.spec.luau` run.
- Place instances (Studio MCP dropped mid-check; Tool existence confirmed read-only in
  Edit mode before the drop: `ReplicatedStorage.ToolsStorage."Boba Phone"` = Tool with
  1 LocalScript child): `RequiresHandle=false` value, `SelectorModels` Cup/Pastry contents,
  which launch items have nil `View.Model` (they render name-only cards), legacy image-id
  load failures (reported, not substituted), `StarterGui.UIArchive.OldUI.BobaPhone` art
  source paths, `PlayerGui.BobaPhone` overlap check, phone-body Frame + UIAspectRatio/
  UISizeConstraint exact values (code uses body AnchorPoint .5,1 / Size {0.3,0},{1,-20} /
  Position {0.5,0},{1,-70}, aspect 0.5, max-height 500, corner 0.125 from evidence +
  MobileOrder precedent).
- Server-side `CreateOrder`-while-clocked-in refusal IS implemented (Jack approved the
  small OrderService edit, follow-up commit): `Client:CreateOrder` returns
  `{ Success = false, Message = "Clock out to order with the phone." }` when
  `server:_isClockedIn(player)`, before the debounce check; no order stored, no debounce
  started. Same message as the phone client guard. Covered by three
  `OrderService.spec.luau` cases (refuse + no state change, order-after-clock-out,
  unresolved-ShiftService still orders). Serve path untouched (attribute read only).

## R1 findings (verify, do not fix; no kitchen/serve file touched)
- `OrderService.collectTools` collects every Tool (character + Backpack); `FindServeTools`
  skips only `Served == true` and grades the rest with `OrderSpec.Match`. The phone has no
  `Item` attribute, so `Match` returns Wrong for it and `PickTools` simply never picks it:
  an extra attribute-less tool changes neither the grade nor the tools picked.
- While the phone is held, `FindFirstChildWhichIsA("Tool")` helpers see the phone, not a
  drink: `KitchenService/Actions/{GiveTool,RenameToolHolding,SetToolAttributes,
  SetToolHoldingProperty,ToolAttributeCheck,ToolNameValidityCheck}`,
  `InteractionRunner.getHeldTool`, `PourMoments.getHeldTool`,
  `KitchenController.heldToolAttributes` (L110), `OrderTicket` held-tool watch (L322),
  `TrashService.getTool`. E.g. `SetToolAttributes` would write Item/Size attributes onto
  the phone. R3 makes this moot for staff (no phone while clocked in). If a fix is ever
  wanted: guard with `tool:GetAttribute("BobaPhone") ~= true` (PENDING JACK).

## Studio steps (Jack, one run)
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