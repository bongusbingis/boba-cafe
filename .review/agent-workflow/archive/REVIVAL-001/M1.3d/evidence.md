RESULT: PASS

# REVIVAL-001 / M1.3d (Mason)

Scope: the M1.3d row of M1.2/design.md section 9, behaviour from M1.1/design.md section 5. Only `src/server/Modules/OrderService.luau` and `src/server/Tests/OrderService.spec.luau` were edited. Not committed. No Studio run, so TestEZ has NOT been run (pending the batched Gauge pass). No NPC serving, assignment or payouts (Q1, Q2, Q5 pending). No reward, currency or quest amounts changed. Kitchen files untouched.

## Source state

- HEAD: `2bdbba1` (working tree also holds M1.3c's uncommitted kitchen edits, which I did not touch).
- sha256 after the last edit:

```
42698285c255a411200972cab12adaed7c3e61a785c0ad5631fbe34d4905cb59  src/server/Modules/OrderService.luau
7136d22a1c2e9beacf19275eab65e4b0b5a12c04cbf67f358f47decb10ab50e9  src/server/Tests/OrderService.spec.luau
```

## API

Added (server-only methods on the service table, not on `Client`):
- `OrderService:FindServeTools(player, specs) -> ({Tool}?, Grade, {string})`. Candidates are `collectTools(player.Character, player.Backpack)` (held tool first, then backpack). Builds `tool:GetAttributes()` for each and calls `OrderSpec.PickTools`. Read-only (does not move tools) and never yields. Returns `nil, "Wrong", reasons` on a miss.
- `OrderService:GetPendingCount() -> number`. This is the old `_getPendingCount`, renamed (no alias kept; the only caller was `_updateStaffScreens`).
- `OrderService:HasActiveOrder(player) -> boolean`: true while the player has a `Being Prepared` order.

Changed:
- `_addOrder(customerId, orderItems, specs)` takes the specs as a third argument and stores `order.specs`. Orders also get `order.grade` on a successful deposit. `Order` type updated.
- `buildOrderItem` (the existing CreateOrder validator; M1.1 called it `validateOrderItem`) now also calls `OrderSpec.FromOrderItem` on the rebuilt item and returns `item, spec, reason`. A failure there rejects the whole order with `Invalid order.` (same message, warn names the reason).

Removed:
- `_promptToolSelection`, the `Promise` require, `_areaDebounces` (field and the check at the top of `_handlePickUp`), and `_dialogService` (field and its `KnitStart` resolution). All were used only by the selection prompt.
- `_getPendingCount` (renamed, see above).

## Behaviour changes

- Staff deposit (`_handlePickUp`, staff path) is synchronous. It calls `FindServeTools(player, order.specs)`.
  - Miss (wrong item, wrong field, or missing tool): fires `Announcement("Cannot Deposit Order!", "<reasons>. Check your order notepad and return when ready.", COLOR_ERROR)` and returns. Nothing else changes: the order stays Being Prepared, the area is not claimed, no folder or models are made, no signals other than Announcement fire, the tools stay where they were.
  - Hit (Perfect or Close): the existing steps run unchanged and in the same block: set `OrderOwner`, hide free nodes for the barista, `NotepadUpdated "ResetOrder"`, `OrdersPrepared` stat, status Ready for Pick Up, `order.grade = grade`, pick-up folder, display models, tools parented to `Order_<customerId>`, customer prompt.
- The barista no longer picks tools from a dialog; the match is automatic. A Close tool is accepted on a player order; the grade is only stored. No tip, pay or quest effect.
- Reason text (display only, `REASON_TEXT`): Item = "Wrong item" and Size = "Wrong size" are from M1.1 section 5. The others are my wording in the same pattern (Syrup, Tapioca, Iced, Sugar = "Wrong syrup/tapioca/ice/sugar"; Missing = "An item is missing"). Multiple reasons are joined with ", ".
- Tools without an `Item` attribute (made before M1.3c, gamepass or legacy tools) never match; they read as "Wrong item".

## Tests (`OrderService.spec.luau`)

- Fixture `makeItem()` is now `{Category="Coffees", Item="Regular", CustomInfo={Size="Medium"}}` plus the server Menu `DefaultInfo`. `makeOrder` derives `specs` from its items; `addOrder` helper replaces direct `_addOrder` calls. `makeArea` is now a Part (a successful deposit reads `area.CFrame`; the real nodes are parts). `_areaDebounces` dropped from the saved/reset fields.
- New/changed describes: `GetPendingCount` (renamed), `HasActiveOrder` (6), `FindServeTools` (14: match, Close, extra attributes, wrong item, two mistakes, name ignored, no attributes, no tools, no Character, held tool first, Perfect beats Close, multi-spec order, Missing, read-only), `CreateOrder` specs stored (1), `_addOrder` stores specs (1), staff deposit (12: match, held tool, Close, multi-item, wrong item, two mistakes, attribute-less tool, one wrong of two, retry after fixing, insufficient tools, area released, no active order), tool collection (3, now through real deposits). Removed: the per-area debounce test.
- UNVERIFIED: none of these have been run. There is no headless runner; Selene/StyLua/rojo only prove syntax and the build.

## Gate

`scripts/gate.sh src/server/Modules/OrderService.luau src/server/Tests/OrderService.spec.luau`:

```
PASS  src/server/Modules/OrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  src/server/Tests/OrderService.spec.luau  selene new=0 (baseline[HEAD]=1 now=0)  stylua=ok
PASS  rojo build -> /var/folders/7d/n36x8s6n387bhfdj5j1z0s500000gn/T/gate-build.rbxl
GATE: PASS
```

(The `pre-existing stylua drift` on OrderService.luau is the `NumPending.Text` line in untouched code at HEAD.)

## Questions for Jack (not blocking)

1. Reason wording for Syrup, Tapioca, Iced, Sugar and Missing (see above) is mine; the design only gives Item and Size.
2. A deposit into an area that already has an owner is still unguarded (as before this task): two baristas who both saw the same free node can deposit into it one after the other, and the second overwrites `OrderOwner`. The old selection window only covered the dialog. Add an "area is occupied" refusal? It is a one-line guard; I did not add it because it is outside the M1.3d row.

## Risks

- Until M1.3c's attribute writes are in the kitchen and the place runs it (M0.1 is pending), no real tool carries `Item`, so every real deposit will be refused with "Wrong item". The M0.4 section 4 round trip depends on M1.3c landing first.
- `_handlePickUp` still types `area` as `Model` although the nodes are parts (pre-existing).
- OrderService now requires `ReplicatedStorage.Shared.Ordering.OrderSpec` at load (`Shared` is Rojo-synced, same as CapsuleService). OrderSpec requires Menu lazily, so a Menu failure still only stops ordering.

## NEXT

- Gauge: run TestEZ (OrderService.spec, OrderSpec.spec) and the Studio round trip as in M0.4 section 4, after M1.3c.
- Client counterpart of the removed prompt: none dedicated. `_promptToolSelection` used the generic `ActionPrompt` dialog through DialogService (`src/shared/UI/Components/Dialogs/ActionPrompt.luau`, also used by `KitchenService/InteractionRunner.luau` and `Pages/Inventory/InventoryComponent.luau`). `src/client/Modules/OrderController.luau` has no selection state; it handles `NotepadUpdated`, `PickUpNodeVisibilityChanged` and `Announcement` as before. Nothing to delete client-side. The existing Announcement path shows the new reason text.
- M1.4: CustomerService should call `OrderService:FindServeTools(player, { npc.Spec })` and `HasActiveOrder` / `GetPendingCount` for its assignment rules (Q1, Q2 first).
