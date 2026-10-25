# REVIVAL-001-M1.1: OrderSpec, tool attributes, matching (Architect)

- Source commit: `92f6144`, read on 2026-10-13. Other agents are editing code at the same time, so line references can drift. The symbols named here are the contract.
- Inputs: `Menu.luau`, `Recipes.luau`, `RecipeConstructors.luau`, `KitchenTypes.luau`, `KitchenService/**`, `OrderService.luau`, `Pages/MobileOrder`, `Pages/Ordering`, `Tests/OrderService.spec.luau`, and the Studio station list supplied by Prime.
- Scope: design only. No production code was changed.

## 0. Findings that shape the design

1. **Names lose information.** The syrup step renames the tool to `Milk + X Syrup`, the coffee step to `Regular`, and the tea step to `Green Tea`. Each of these drops the size and the cup. Matching has to use attributes. Names stay as they are, because the `ToolNameValidityCheck` gates depend on them.
2. **The client sends `DefaultInfo`, and the server trusts it.** It is the whole Menu table. Order items also do not carry their category, and `Item` is a per-category key that repeats across categories (`"Vanilla"` exists in Hot Cocoas, Ice Creams, Macarons and Mochis). The client must add `Category`. The server must look the item up in `Menu.FoodTable` and use its own copy of the definition.
3. **There is no `Sink` station in the Studio list.** Every tea and water recipe needs the Sink step (`#Water`).
4. **The Ice Machine accepts only the exact coffee name** (`=Regular`). Ice must go in before sugar (`Regular + Sugar` fails the check).
5. **Blender:** tapioca requires ` Milk` or `Tea` in the tool name. So the Blender step is mandatory for every syrup except Classic Milk Tea, Thai Milk Tea and Green Tea. This is acceptable, but the recipe card (M1.5) must show the Blender step.

## 1. Content reconciliation

Status assumes M0.1 delivers `SharedStorage.Tools.Kitchen.*`, the station proxies and the syrup dispensers. Tool template names are UNVERIFIED (§7).

| Menu category / item | Path today | Status |
|---|---|---|
| Boba Teas › Custom Boba | Clear Cup → Milk → `<S> Syrup` → Blender (see §0.5) → `<T> Tapioca` → Lids | **Works** for the **17** syrups that appear in both lists: Classic Milk Tea, Strawberry Banana, Taro, Mango, Coconut, Matcha, Chocolate Banana, Passion Fruit, Thai Milk Tea, Strawberry, Brown Sugar, Lychee, Chocolate, Green Tea, Raspberry, Cherry, Guava. All 10 tapioca flavours match. All 3 sizes work. |
| Syrups on the Menu with no dispenser | Banana, Avocado, Honeycomb, Almond, Mint, Orange, Blueberry, Peach | Small addition: one line each in `Recipes.Syrups` (the dispenser spawns automatically). Otherwise remove them from the Menu's `SyrupFlavor`. Forge decides. Watermelon and Dragon Fruit have dispensers but are not on the Menu. |
| Boba Teas › Matcha Tea Boba | Same path, with Matcha syrup | **Works** |
| Coffees (Regular, Espresso, Decaf, Cappuccino, Americano, Cortado, Koa Coffee) | Cup → Coffee Machine → [Ice Machine] → [Sugar] → Lids | **Works**, with ice before sugar (§0.4) |
| Coffees › Latte | Not offered by the Coffee Machine | Small addition: a `Latte` button and a `makeCoffeeVariant("Latte", …)` branch |
| Teas (Green, Lemon, Peach, Earl Grey, Vanilla Chai, Caramel Chai) | Cup → **Sink** → powder → [Ice Machine] | **Blocked:** Rigger must add a `Sink` proxy Model. No new asset is needed. |
| Teas › Oolong | The powder giver exists; there is no recipe | Small addition: `makeTeaVariant("Oolong Tea", …)`. Also needs the Sink. |
| Hot Cocoas: Classic, Caramel, Vanilla | Mug → Milk (`Mug + Steamed Milk`) → powder | **Works** |
| Hot Cocoas › Salted | The giver exists; there is no recipe | Small addition: `makeHotChocolateVariant("Salted", …)`. A Peppermint giver also exists but is not on the Menu (adding it is a Menu/product call). |
| Smoothies (16) | No Fruits Freezer recipe. The Blender recipe makes flavoured milk only. Fruit tools are unverified. | **Not feasible** without a new recipe design and assets. Remove them from the launch Menu. |
| Pastries › Fudge Brownie | Food Display | **Works** |
| Pastries: the other 13 | Not in the Food Display list | Small addition (one list line each) **if** a `Tools.Pastry[...]` Tool exists, which is UNVERIFIED. Otherwise not feasible. |
| Macarons (8) | Food Display | **Works** |
| Mochis (5) | Food Display | **Works.** `Orange Cream Mochi` must serve as the Tool `Orange Mochi` (`ServeItem`, §2). |
| Ice Creams (12) | Ice Cream Freezer | **Works** |
| Others › Milk | Clear Cup → Milk | **Works** |
| Others › Flavored Milk | Clear Cup → Milk → Syrup → Blender | **Works** for the 17 syrups |
| Others › Cup | Clear Cup giver | **Works** (`ServeItem = "Clear Cup"`). Suggest dropping it; it adds nothing to play. |
| Others › Water | Cup → **Sink** → [Ice] | **Blocked** by the missing Sink |

**Launch menu (works today):**

| Category | Items |
|---|---|
| Boba Teas | Custom Boba and Matcha Tea Boba: 17 syrups × 10 tapioca × 3 sizes |
| Coffees | 7, with Iced and Sugar |
| Hot Cocoas | 3 |
| Food Display and freezer | Fudge Brownie, 8 macarons, 5 mochis, 12 ice creams |
| Others | Milk, Flavored Milk |

Teas and Water join once the Sink exists. Smoothies, Latte, Salted cocoa and the other 13 pastries stay off until their additions land.

**M1 slice: all three items can be made today, given M0.1.**

| Slice item | Path |
|---|---|
| Classic Milk Tea Boba | `{Category="Boba Teas", Item="Custom Boba", CustomInfo={Size="Medium", ["Syrup Flavor"]="Classic Milk Tea", ["Tapioca Flavor"]="Normal"}}`. Clear Cup → Milk → Classic Milk Tea Syrup → Normal Tapioca. The Blender step is optional for this syrup. |
| Regular Coffee | Cup → Coffee Machine › Regular |
| Fudge Brownie | Food Display |

## 2. OrderSpec

New file `src/shared/Ordering/OrderSpec.luau` (`--!strict`, pure, used by both server and client: the server validates with it, and the client can use it for the ticket and recipe card).

```lua
export type Grade = "Perfect" | "Close" | "Wrong"
export type OrderSpec = {
	Kind: "Drink" | "Grab",
	Item: string,        -- compared with the tool's "Item" attribute
	Size: string?,       -- "Small" | "Medium" | "Large" | "Mug"; Drinks only
	Syrup: string?,      -- set when the item has RequiredSelection "Syrup Flavor"
	Tapioca: string?,    -- set when the item has RequiredSelection "Tapioca Flavor"
	Iced: boolean?,      -- nil = the item has no ice option
	Sugar: boolean?,     -- nil = the item has no sugar option
	Label: string,       -- "Medium Custom Boba" (same format as the staff screen)
}

OrderSpec.FromMenuItem(def: table, customInfo: table): (OrderSpec?, string?)  -- pure; tested
OrderSpec.FromOrderItem(orderItem: { Category: string, Item: string, CustomInfo: table }): (OrderSpec?, string?)
    -- looks up Menu.FoodTable[Category].Items[Item], then calls FromMenuItem
OrderSpec.Match(spec, attrs: { [string]: any }): (Grade, { string })
OrderSpec.PickTools(specs: { OrderSpec }, candidates: { { [string]: any } }): ({ number }?, Grade, { string })
```

How `FromMenuItem` derives each field. Any invalid input returns `nil, "<field>"`. The client's input is never trusted.

| Field | Rule |
|---|---|
| `Kind` | `"Drink"` if `def.Select.Size` exists, else `"Grab"` |
| `Item` | `def.ServeItem or def.ItemName` |
| `Size` | `customInfo.Size` must appear in `def.Select.Size` |
| `Syrup`, `Tapioca` | `customInfo["Syrup Flavor"]` / `customInfo["Tapioca Flavor"]` must be a key of the matching `def.RequiredSelection` table. Required when that table is present. |
| `Iced` | Read from `customInfo.Iced`, or from `customInfo.Ice` for Water. Must be a boolean; otherwise use the `def.Options` default. `Sugar` uses the same rule. |

**Menu data additions** (data only, no prices):

| Menu item | Field to add |
|---|---|
| `Custom Boba`, `featuredMatcha` | `ServeItem = "Boba"` |
| Mochis › Orange Cream | `ServeItem = "Orange Mochi"` |
| Others › Cup | `ServeItem = "Clear Cup"` |

## 3. Tool attributes

The attribute names are `Item`, `Size`, `Syrup`, `Tapioca`, `Iced`, `Sugar` and `Lid`. None of these is used by any other code (the attributes in use today are `AutoWeld`, `CleaningSpill`, `ManagedParticle`, `IsAdmin` and `Restocking`). Kitchen tools live in the server-owned character, so a client cannot forge these attributes.

**New action:** `src/server/Modules/KitchenService/Actions/SetToolAttributes.luau`. It takes `(player, model, attrs: {[string]: any}) -> boolean`, calls `SetAttribute` for each pair on the held tool (found with the same `getHeldTool` as the other actions), and returns `false` if there is no held tool. Values are literals only.

**GiveTool change:** add an optional third argument `attributes`. GiveTool always sets `Item = toolToClone.Name` first, then applies `attributes`. This marks every grab item (pastries, macarons, mochi, ice cream) automatically. `makeGrabSelector` does not change.

Append each attribute write as the **last** step of its sequence, so a gate or rename that fails leaves the tool unmarked:

| Recipe / constructor | Add |
|---|---|
| `makeCupGiver(name)`, each size branch | `{ "GiveTool", Tools.Cups[size.." "..name], { Item = name, Size = size } }` |
| `Mug` | `{ "GiveTool", Tools["Mug"], { Size = "Mug" } }` |
| `Sink`, both branches | `{ "SetToolAttributes", { Item = "Water" } }` |
| `Milk` | `{ Item = "Milk" }` |
| `makeCoffeeVariant(name)` | `{ Item = name }` |
| `makeTeaVariant(name)` | `{ Item = name }` |
| `makeHotChocolateVariant(flavor)` | `{ Item = flavor == "" and "Hot Chocolate" or flavor.." Hot Chocolate" }` |
| Syrup loop | `{ Item = "Flavored Milk", Syrup = name }` |
| Tapioca loop | `{ Item = "Boba", Tapioca = <flavor key> }`. Capture the key **before** `name = name .. " Tapioca"`. |
| `Ice Machine` | `{ Iced = true }` |
| `Sugar` | `{ Sugar = true }` |
| `Lids` | `{ Lid = true }`. Recorded for the recipe card only; not matched in M1. |
| `Blender` | none |

## 4. Matching (`OrderSpec.Match`)

| Step | Rule | Result |
|---|---|---|
| 1 | `attrs.Item ~= spec.Item` | `Wrong, {"Item"}` |
| 2 | `Kind == "Grab"` | `Perfect, {}` |
| 3 | `spec.Syrup` is set and `attrs.Syrup ~= spec.Syrup` | `Wrong, {"Syrup"}` |
| 4 | Collect minor mistakes in this fixed order: `Size`, `Tapioca`, `Iced`, `Sugar`. Fields that are `nil` in the spec are skipped. A missing boolean attribute counts as `false`. | 0 mistakes: `Perfect`. Exactly 1: `Close` (reduced tip). 2 or more: `Wrong`. The reasons list is the collected fields. |

"Close" means exactly one small mistake.

`PickTools` works on one shared list of candidate tools, in this order: the held tool, then the backpack in `GetChildren` order. It makes two passes. Pass 1 gives each spec its first unused **Perfect** candidate. Pass 2 gives each spec that is still unfilled its first unused **Close** candidate. Each tool is used at most once.

- If every spec is filled, it returns the chosen candidate indices and the overall grade: `Close` if any pick was Close, else `Perfect`.
- If any spec is unfilled, it returns `nil, "Wrong", reasons`. For a single spec, `reasons` is `Match` against the first candidate. With more specs it is `{"Missing"}`.

**TestEZ cases** (`src/server/Tests/OrderSpec.spec.luau`). The fixtures are plain tables; no Instances are needed.

| Spec | Name | Fields |
|---|---|---|
| A | Boba | `Drink`, `Boba`, Medium, Classic Milk Tea, Normal |
| B | Coffee | `Drink`, `Regular`, Small, Iced=false, Sugar=false |
| C | Brownie | `Grab`, `Fudge Brownie` |
| D | Cocoa | `Drink`, `Caramel Hot Chocolate`, Mug |

| # | Call | Input | Expected |
|---|---|---|---|
| 1 | Match A | the exact attributes, plus `Lid=true` | Perfect, {} |
| 2 | Match A | Size=Large | Close, {Size} |
| 3 | Match A | Tapioca=Strawberry | Close, {Tapioca} |
| 4 | Match A | Syrup=Taro | Wrong, {Syrup} |
| 5 | Match A | Size=Large and Tapioca=Strawberry | Wrong, {Size, Tapioca} |
| 6 | Match A | Item=Flavored Milk (no tapioca) | Wrong, {Item} |
| 7 | Match B | {Item=Regular, Size=Small} | Perfect |
| 8 | Match B | plus Iced=true | Close, {Iced} |
| 9 | Match B | plus Iced=true and Sugar=true | Wrong, {Iced, Sugar} |
| 10 | Match B | Item=Decaf | Wrong, {Item} |
| 11 | Match B with Iced=true | {Regular, Small, Iced=true} | Perfect |
| 12 | Match C | {Item=Fudge Brownie, Sugar=true} | Perfect (extra attributes are ignored) |
| 13 | Match C | {} (a gamepass or legacy tool) | Wrong, {Item} |
| 14 | Match D | {Caramel Hot Chocolate, Mug} | Perfect |
| 15 | Match D | {Item=Milk, Size=Mug} | Wrong, {Item} |
| 16 | PickTools {B(Medium), B(Small)} | [Small Regular, Large Regular] | picks {2, 1}, Close |
| 17 | PickTools {A} | [Regular coffee, perfect Boba] | picks {2}, Perfect |
| 18 | PickTools {C, C} | [Brownie] | nil, {Missing} |
| 19 | FromMenuItem Custom Boba | Medium / Classic Milk Tea / Normal | equals spec A |
| 20 | FromMenuItem Custom Boba | no Tapioca Flavor | nil, "Tapioca Flavor" |
| 21 | FromMenuItem Coffee | Size="Huge" | nil, "Size" |
| 22 | FromMenuItem Water | {Size=Small, Ice=true} | Iced=true |
| 23 | FromMenuItem Orange Cream Mochi | {} | Grab, Item="Orange Mochi" |

## 5. Serve flow

There is one server entry point, `OrderService:FindServeTools(player, specs) -> ({Tool}?, Grade, {string})`. It collects candidate tools (reusing `collectTools`, with the held tool first), builds `tool:GetAttributes()` for each, and calls `PickTools`. It never yields.

**Player order (deposit):**

- `Client:CreateOrder` derives specs with `FromOrderItem`. If any item fails, it rejects the whole order with `{ Success = false, Message = "Invalid order." }`. For each item it replaces `DefaultInfo` with the server's Menu `def` and stores `order.specs`.
  - Note: the working tree already has a concurrent edit (not in commit 92f6144) that adds `validateOrderItem` and a `CreateOrderResult` return to OrderService. Put the `FromOrderItem` call inside `validateOrderItem` rather than adding a second check.
- In the staff path of `_handlePickUp`, the count check and `_promptToolSelection` are replaced by `FindServeTools(player, order.specs)`:
  - On failure, it fires the existing `Announcement("Cannot Deposit Order!", <reason text>, COLOR_ERROR)` and changes nothing.
  - On success, it runs the existing code synchronously: it parents the tools to `Order_<id>`, places the display models, sets `order.grade = grade`, and sets the status to Ready.
- Delete `_promptToolSelection`. With no Promise in this path, the area-debounce window goes away.
- OrderService owns the tools and moves them to the pickup folder, as today.

**NPC (M1.4, `CustomerService`):**

- When the NPC prompt is triggered, it calls `FindServeTools(player, { npc.Spec })`.
- On Perfect or Close, CustomerService destroys the tool, pays out (M1.4), and sends `DialogService:Notify` with "Perfect!" or "Close: wrong size".
- On Wrong, it keeps the tool and sends `Notify` with the reason. Nothing else happens.
- NPC specs are built from launch-menu order items through the same `FromOrderItem`, so there is one path.
- The internal result is `{ Success, Grade, Reasons, Message }`. M1 needs no new remote.

Reason text lives in a client- or server-side map: `Item` → "Wrong item", `Size` → "Wrong size", and so on. It is a lookup, not logic.

## 6. Interfaces, ownership, and the order Mason should work in

Steps 1–3 are M1.3. Step 4 can run in parallel once step 1 lands.

| # | File | Side | Change |
|---|---|---|---|
| 1 | `src/shared/Ordering/OrderSpec.luau` and `src/server/Tests/OrderSpec.spec.luau` | shared / test | New. Types, `FromMenuItem`, `FromOrderItem`, `Match`, `PickTools`, and the 23 cases. |
| 2 | `src/shared/Ordering/Menu.luau` | shared | Add the 4 `ServeItem` fields. Trimming to the launch menu is a Forge/M1.2 decision, applied here. |
| 3 | `KitchenService/Actions/SetToolAttributes.luau` (new), `Actions/GiveTool.luau`, `shared/Kitchen/Recipes.luau`, `RecipeConstructors.luau` | server / shared | §3. The optional recipe additions (Oolong, Salted, Latte, syrups) apply only if Forge puts those items on the launch menu. |
| 4 | `Pages/MobileOrder/init.luau` (`onAddItem`), `Pages/Ordering/init.luau` (`onAddToOrder`) | shared UI | Add `Category = selectedCategory / selCategory` to each order item. |
| 5 | `src/server/Modules/OrderService.luau` | server | `FindServeTools`, spec derivation in `CreateOrder`, a synchronous deposit, and deletion of `_promptToolSelection`. Update the `makeItem()` fixture in `OrderService.spec.luau` to `{Category="Coffees", Item="Regular", CustomInfo={Size="Medium"}}`. |
| 6 | `CustomerService` (M1.4) | server | Consumes `FindServeTools`. |

## 7. Risks and unverified items

- **Name stability.** Do not change any `RenameToolHolding` output or `ToolNameValidityCheck` term in this task. The odd names (`" Hot Chocolate"` with a leading space, `"Classic Boba Tea Boba"`) are cosmetic and belong in a separate task.
- **The kitchen cannot run until M0.1.** `SharedStorage.Tools.Kitchen` and `Animations.Kitchen` are missing (recon-memo), and `Recipes` errors when required. UNVERIFIED:
  - the tool names `Small/Medium/Large (Clear) Cup`, `Mug` and `Tools.Pastry.*`;
  - that the tools have `Liquid`, `Tapioca` and `CoffeeLid` children (`SetToolHoldingProperty` silently skips a missing child);
  - whether clear cups have a `CoffeeLid`.
- **Missing Sink** blocks Teas and Water. This is a Rigger task.
- **Lid/Lids.** The recipe key is `Lids`. Until the Studio models are renamed, there is no lid prompt. The slice does not depend on lids.
- **Partial sequences.** `InteractionRunner` has no rollback. Putting the attribute writes last keeps a failed step from marking the tool.
- **No yield between pick and move or destroy.** Keep `FindServeTools` and the parent/destroy step in the same synchronous block.
- **Old data.** Tools made before the update, or given by gamepasses, have no `Item` attribute. They are never matched or consumed, which is safe.
- **Optional extra.** The dead quest check (`CurrentItem == "[Syrup] Boba"`) can become `tool:GetAttribute("Item") == "Boba"`.
