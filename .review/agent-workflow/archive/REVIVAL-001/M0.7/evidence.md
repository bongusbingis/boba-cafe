# REVIVAL-001-M0.7 evidence (Mason)

Task: boba cannot be made with 16 of 19 syrups (Gauge M0.4 runtime-2).
Source state: HEAD 92f6144 plus pre-existing uncommitted work; pre-edit copies in /private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m07-pre/. Post-edit shasums:
```
b4af8709d08e802f39df1bd10c1b6a4088228572  src/shared/Kitchen/Recipes.luau
523f0717d0f73d495f972a0bd8a5fc9e642b28f5  src/server/Modules/OrderService.luau
2e1bbf064b8e921a36c93e7ff98af15f5a0757a4  src/server/Modules/KitchenService/Actions/ToolNameValidityCheck.luau
7e9699239c22397432f30fbe5e54d2cce6d48859  src/server/Tests/BobaRecipe.spec.luau
```

## Root cause
Wiring was Cup -> Milk -> Syrup -> Blender -> Tapioca. Blender renames "Milk + X Syrup" to "X Milk", which passes the old "# Milk" check. Without Blender the name stays "Milk + X Syrup" and the old check only passed for syrups containing " Milk" or "Tea". The old gsub("Milk","Boba") also rewrote every "Milk" in the flavor.

## Change
- Tapioca check now: `#^Milk %+ .+ Syrup|#^[^%+]+ Milk` (straight-from-syrup or blended names; rejects "Small Clear Cup + Milk" and "Mug + Steamed Milk").
- Tapioca rename: "Milk + F Syrup" or "F Milk" -> "F Boba"; text after the flavor (e.g. " + Sugar") is kept; no-match returns the old name.
- OrderService quest check: `string.find(currentItem, " Boba", 1, true)`; CurrentItem fallback is now item.Name (nothing in src writes CurrentItem).
- ToolNameValidityCheck debug print removed.
- New spec src/server/Tests/BobaRecipe.spec.luau.

## Final name chain (format "{Syrup} Boba")
Start "Small Clear Cup + Milk" (size text is lost at the Syrup step, as before):
- Taro: "Milk + Taro Syrup" -> (Blender "Taro Milk") -> "Taro Boba"
- Classic Milk Tea: "Milk + Classic Milk Tea Syrup" -> (Blender "Classic Milk Tea Milk") -> "Classic Milk Tea Boba"
- Dragon Fruit: "Milk + Dragon Fruit Syrup" -> (Blender "Dragon Fruit Milk") -> "Dragon Fruit Boba"
Verified in lune with the same patterns for all 19 syrups, blended and unblended: 0 mismatches.

## Consumers checked (grep of src for tool-name use)
- Lids recipe: no name check (only sets CoffeeLid transparency); unaffected.
- Sink "#Cup|!Milk", Blender "#Milk","#Syrup", Ice Machine, Sugar "!Sugar": unchanged. Sugar after Tapioca gives "X Boba + Sugar" (quest check still matches).
- OrderService deposit/pickup: lists tools by Name only (line ~244, ~634); no format match. Menu.luau/ItemName are display names, not matched against tool names.
- OrderService quest check (_handlePickUp ~:691): updated.
- Not covered: M1.1 design proposes an "Item" attribute for serve matching; untouched.

## Gates
- selene (0.31.0) on 3 changed files + new spec: 0 errors, 0 warnings, 0 parse errors (pre: 0).
- stylua 2.5.2 --check diff-line counts post vs pre: Recipes 9/9, OrderService 7/7, ToolNameValidityCheck 70/72 (all pre-existing, no new); new spec passes.
- rojo build default.project.json -o /private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m07.rbxl: built.
- TestEZ spec NOT run (needs Studio).
