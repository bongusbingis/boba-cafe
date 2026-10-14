RESULT: PASS

# REVIVAL-001 / M1.3c: kitchen stations write tool attributes (Mason)

Scope: M1.2/design.md section 9 row M1.3c, implementing M1.1/design.md section 3. Not committed. No Studio run. `OrderService.luau` and its spec were not touched (another Mason's lane). M1.3d not touched.

## Source state

- HEAD: `2bdbba1` (working tree also holds the other Mason's uncommitted OrderService edits).
- sha256 after the last edit:

```
ca130d1343dc4b51384b84055c122629275c0d336930c82e4045be521da04b74  src/server/Modules/KitchenService/Actions/SetToolAttributes.luau  (new)
0d73325157af8b8cc6e1e3b60ba59a5bc2ea09ec0b77ee03204296684f46c4d2  src/server/Modules/KitchenService/Actions/GiveTool.luau
534786016852bed892e269e918b9afed03d4f65bc6a836d51a60f89040d91d3a  src/shared/Kitchen/Recipes.luau
94a5c42fa4f7c89c0e759eb6720a60d261da4ad761bc1a6cfcf69fc2d4cd4300  src/shared/Kitchen/RecipeConstructors.luau
19e72eea853e773f1334e37586d6cedc5d0cf9476f1c7255808512ab740e62f6  src/server/Tests/KitchenAttributes.spec.luau  (new)
2ca73f297be3f77d0f495feb490d60c3d403487cdbec4da2b38cec664b0340d7  src/server/Tests/BobaRecipe.spec.luau  (NOT edited)
```

## Semantics confirmed from OrderSpec.Match (HEAD `2bdbba1`)

- `attrs.Item ~= spec.Item` is Wrong. `spec.Item` is the Menu `ServeItem or ItemName`.
- Grab spec: Perfect once Item matches (other attributes ignored).
- Drink: `Syrup` differs is Wrong. `Size`, `Tapioca`, `Iced`, `Sugar` are minor mistakes (1 = Close, 2+ = Wrong). A missing boolean attribute counts as false, so a tool never needs `Iced=false` or `Sugar=false` written.
- Tool names are never read.

## What changed

- `Actions/SetToolAttributes.luau` (new): `(player, model, attrs) -> boolean`. Finds the held tool the same way as the other actions, returns false with no held tool, and validates every pair (string key, string/boolean/number value) before writing any, so a bad entry sets nothing. `KitchenService` registers every module in `Actions/` automatically, so no registry edit.
- `Actions/GiveTool.luau`: new optional 4th parameter `attributes` (the recipe's third argument). The clone gets `Item = toolToClone.Name` first, then `attributes`, before it is parented to the character. Bad attributes are refused before the held tool is moved to the backpack. File kept in its existing 4-space style (pre-existing stylua drift; see gate).
- `shared/Kitchen/RecipeConstructors.luau`: `grabActions(tool, attributes?)`; `makeCupGiver` passes `{ Item = name, Size = size }` ("Cup"/"Clear Cup"); coffee, tea and hot-chocolate variants end with `SetToolAttributes { Item = <menu name> }`. Plain hot chocolate writes `Item = "Hot Chocolate"` (the Menu name); the tool rename is unchanged.
- `shared/Kitchen/Recipes.luau`, each as the LAST step: Mug `GiveTool ... { Size = "Mug" }` (Item defaults to "Mug"); Sink, both branches `{ Item = "Water" }`; Milk `{ Item = "Milk" }`; Sugar `{ Sugar = true }`; Ice Machine `{ Iced = true }`; Lids `{ Lid = true }`; every Syrup `{ Item = "Flavored Milk", Syrup = <key> }`; every Tapioca `{ Item = "Boba", Tapioca = <key> }` (key captured as `tapiocaFlavor` before the " Tapioca" suffix is added). Grab selectors (Food Display, Ice Cream Freezer) are unchanged: GiveTool's default `Item = tool name` marks them.
- **Blender writes nothing** (pending Jack's Q3). Pointer: `Recipes.luau`, `["Blender"].Actions`, a comment after the RenameToolHolding step. If Jack requires the Blender: add `{ "SetToolAttributes", { Blended = true } }` at that comment (1 line) plus a `Blended` field in `OrderSpec.Match` (1 line).
- `src/server/Tests/KitchenAttributes.spec.luau` (new, 34 `it`): real Recipes data and real actions on real Tool/Model instances, a small runner that follows SelectFrom branches. Covers the three slice items (and the boba with the Blender in the chain, giving identical attributes), grading all three Perfect through `OrderSpec.FromMenuItem` + `Match`, every other station, 9 refused-gate cases (attributes and name unchanged), the two actions, and Menu consistency (every written `Item` other than raw Cup/Mug is a Menu `ServeItem or ItemName`; every tapioca key is on the Custom Boba). `BobaRecipe.spec` is unedited and still passes.

## Attribute output per slice item (lune harness, real action and recipe code)

```
Medium Custom Boba:           tool name 'Classic Milk Tea Boba' attrs {Item=Boba, Size=Medium, Syrup=Classic Milk Tea, Tapioca=Normal}
Medium Custom Boba (blended): tool name 'Classic Milk Tea Boba' attrs {Item=Boba, Size=Medium, Syrup=Classic Milk Tea, Tapioca=Normal}
Small Regular:                tool name 'Regular'                attrs {Item=Regular, Size=Small}
Fudge Brownie:                tool name 'Fudge Brownie'          attrs {Item=Fudge Brownie}
```

## Checks

- Gate (`scripts/gate.sh` on the 5 changed files):

```
PASS  src/server/Modules/KitchenService/Actions/SetToolAttributes.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/KitchenService/Actions/GiveTool.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  src/shared/Kitchen/Recipes.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=pre-existing stylua drift
PASS  src/shared/Kitchen/RecipeConstructors.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/KitchenAttributes.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /var/folders/7d/n36x8s6n387bhfdj5j1z0s500000gn/T/gate-build.rbxl
GATE: PASS
```

- `lune` 0.10.5 sanity run (throwaway harness in `/private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m13c/`; fake DataModel nodes, a stand-in `SharedStorage.Tools.Kitchen` of hand-made Tools, the real Menu with a stub `SelectorModels`, a minimal TestEZ shim): KitchenAttributes 34/34 pass, BobaRecipe 5/5 pass. The refusal tests have teeth: with a mutated copy (Tapioca marking before its gate, wrong Syrup value) 6 of 34 fail.
- Not a TestEZ-in-Studio run. The lune shim only supports `expect(...).to.equal`, so OrderSpec.spec (which uses `to.be.ok`) was not run there; it is unaffected by this change.

## Findings that are not mine to decide (no change made)

1. Plain `Hot Chocolate Powder` renames the tool to `" Hot Chocolate"` (leading space) because `flavor == ""`. Pre-existing; tool names stay unchanged per the task. The attribute is correct (`Hot Chocolate`).
2. Menu and stations disagree on syrups. Stations with no Menu syrup: Dragon Fruit, Watermelon. Menu syrups with no station: Almond, Avocado, Banana, Blueberry, Honeycomb, Mint, Orange, Peach. A Custom Boba order for one of those eight cannot be made. Tapioca (10) matches exactly. Left unasserted in the spec on purpose.
3. Menu items with no station at all: 16 smoothies, Latte, Oolong Tea, Salted Hot Chocolate, and 13 pastries (Boba Popsicle, 3 Cake Pops, 2 Cookies, Croissant, Chocolate Muffin, Chocolate Eclaire, Cinnamon Roll, Cheesecake, Strawberry Donut, Boba Cupcake). Launch-menu question (the M1.1 doc defers the optional recipe additions to Forge).
4. `Lids` has no validity gate and `SetToolHoldingProperty` returns true when the `CoffeeLid` child is missing, so `Lid = true` is also written onto a tool with no lid part (for example a pastry). `Lid` is not matched in M1 (recipe card only). The `Lids` recipe key vs `Lid` is Q3's asset question.

## UNVERIFIED

- No Studio run. Not checked against the real place: that `SharedStorage.Tools.Kitchen` tools for Cups/Mug/Pastry exist under those names, and that none of them already carries an authored `Item`/`Size`/`Syrup`/`Tapioca`/`Iced`/`Sugar`/`Lid` attribute (the spec's contract-string assertions would show a leaked one). `Instance:Clone()`/weld/`Parent` behavior in Studio rather than lune. TestEZ in Studio is still the batched Gauge pass.
- `docs/SYSTEMS.md` (Kitchen section) not updated: out of write scope. It should gain a line: stations write the OrderSpec tool attributes via `SetToolAttributes` / `GiveTool`.
