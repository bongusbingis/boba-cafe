RESULT: PASS

# REVIVAL-001 M1.5a: OrderSpec.Steps and OrderSpec.StepState

Lane: Mason (S). Scope: `src/shared/Ordering/OrderSpec.luau`, `src/server/Tests/OrderSpec.spec.luau`. No Studio, no commit. Design source: M1.2 design.md 3.2 (chains), 3.8 (card spec), 9 (M1.5a row).

## API (for M1.5b, M1.5c, M1.5d)

```lua
export type Step = {
	Station: string,   -- Recipes.Items key the step uses; also the Model name to highlight
	Choice: string?,   -- dialog button text to pulse at that station; nil when the step opens no dialog
	Label: string,     -- card row text
	Optional: boolean?,-- reserved; NO step sets it yet
}
export type Severity = "Wrong" | "Close"
export type Problem = {
	Step: number?,     -- index into Steps(spec); nil when the mistake has no row (unwanted ice or sugar)
	Severity: Severity,
	Reason: string,    -- first failing field: "Item" | "Syrup" | "Size" | "Tapioca" | "Iced" | "Sugar"
	Reasons: { string },-- every failing field, in OrderSpec.Match order
}

OrderSpec.Steps(spec: OrderSpec): { Step }
OrderSpec.StepState(spec: OrderSpec, attrs: { [string]: any }?): (number, Problem?)
```

- `Steps` returns a fresh table each call. `{}` means "no card chain, hide the card" (teas, water, smoothies, the bare Clear Cup, malformed specs).
- `StepState` returns `(current, problem)`. `current` is the index of the first step not done: 1 when `attrs` is nil (nothing held) or the item has no chain, `#Steps(spec) + 1` when ready to serve. `problem` is nil unless the held tool already carries a mistake.
- Both are pure. `attrs` is `tool:GetAttributes()` of the equipped tool. Tool names are never read.

### Chains (spec fields decide the chain, not names)

| Spec shape | Rows (Station, Choice) |
|---|---|
| Kind Grab | `Food Display` (or `Ice Cream Freezer` when Item ends in " Ice Cream"); Choice = Item |
| Size == "Mug" | `Mug`, `Milk` (label "Steamed Milk"), `<Item> Powder` (e.g. "Caramel Hot Chocolate Powder"); no Choice |
| Syrup and Tapioca set (boba) | `Clear Cup` (Choice = Size), `Milk`, `<Syrup> Syrup`, `<Tapioca> Tapioca` |
| Iced and Sugar both non-nil (coffee) | `Cup` (Choice = Size), `Coffee Machine` (Choice = Item), `Ice Machine` only if Iced == true, `Sugar` only if Sugar == true |
| anything else | no steps |

Done rules follow design 3.8: a row with an Item is done once the tool's Item is that row's Item or a later row's, plus the attribute the row sets (Size, Syrup, Tapioca; Iced/Sugar/Blended need `== true`). The coffee cup row only needs Item and Size set, because the next Item (coffee type) is an open choice.

### Problems (same severities and early returns as Match, so card and serve agree)

1. Item not part of the chain: Wrong, `Reason = "Item"`, shown on `current`.
2. Syrup set and differs: Wrong, shown on the Syrup row.
3. Size / Tapioca / Iced / Sugar set and differs: one is Close; two or more are Wrong. `Step` is the row of the first reason in Match order. Only attributes already set count. Ice or sugar only counts when the spec says no and the tool has it true, so `Step` is nil there (no row).

### REQUIRE_BLENDER (PENDING JACK Q3)

`local REQUIRE_BLENDER = false` in OrderSpec.luau, with a comment pointing to Q3. `true` inserts a `Blender` row between Syrup and Tapioca (the only slot its gate allows: it needs Milk and Syrup in the name, and Tapioca renames them away) that is done when `Blended == true`. Flipping it alone is not enough: Recipes `Blender` must write `{ Blended = true }` and `Match` must grade it, otherwise the row never completes. Verified in a throwaway copy: true gives `Clear Cup > Milk > <Syrup> Syrup > Blender > <Tapioca> Tapioca`, Blended moves current 4 to 5; false gives the 4-row chain.

## Tests added (`src/server/Tests/OrderSpec.spec.luau`)

62 new cases, 54 existing cases untouched and still passing (lune: 54/54 at HEAD, 116/116 now). Table driven (`stateCases`: snapshot, expected current, expected problem).

- Acceptance, 3 slice items: boba (specA), Small Regular (specB), Fudge Brownie (specC). Each step advances; holding nothing (nil and `{}`) gives current 1; a wrong syrup at step 3 is `Wrong` on `Step = 3`; a wrong size is `Close` on `Step = 1`; wrong tapioca is Close on step 4.
- Also: spec B2 (ice and sugar rows, sugar-before-ice order), hot cocoa (specD), ice cream grab, a tea (no chain), malformed spec and non-table attrs, wrong coffee type on the Coffee Machine row, Cup vs Clear Cup, unwanted ice/sugar, two-minor escalation to Wrong, an "agreement with Match" block (problem Severity equals Match grade for finished tools).
- Real Menu block (needs `ReplicatedStorage.SelectorModels`, like the existing Menu cases): slice items give 4/2/1 steps; every Ice Creams item maps to Ice Cream Freezer; every Macarons, Mochis and Pastries item to Food Display.
- The Steps test for spec A asserts exactly 4 rows (no Blender), so flipping `REQUIRE_BLENDER` forces a deliberate test edit.

## Checks

- `scripts/gate.sh src/shared/Ordering/OrderSpec.luau src/server/Tests/OrderSpec.spec.luau`: GATE: PASS (selene new=0 and stylua ok on both files, rojo build ok).
- lune 0.10.5 harness (throwaway, `/private/tmp/claude-501/-Users-jackcrowell-Desktop-boba-cafe/m15a/run.luau`, adapted from the M1.3c harness with a `to.be.ok` shim): `OrderSpec: 116 tests, PASS 116 FAIL 0`, including the real Menu cases (stub SelectorModels).
- Teeth (mutated copies): syrup Wrong to Close fails 3; Close-only escalation fails 4; ice cream suffix changed fails 2; disabling the rank check fails 14; `REQUIRE_BLENDER = true` fails 8 (expected shape changes).
- Not done: TestEZ in Studio (batched Gauge pass). `TESTS_ENABLED` not touched.

## Questions for Jack (nothing here was decided)

- **Q3 (pending):** Blender required? Code ready behind `REQUIRE_BLENDER`; the cost of "yes" is listed above.
- **Q22 (pending):** teas and water have no chain (Steps returns `{}`), as the design says. Same for smoothies and the bare "Cup" (Others > Cup, Item "Clear Cup"): no chain is specified for them. Should the bare Cup get a one-row chain?
- **Grab station:** the spec carries no category, so Ice Cream Freezer vs Food Display is decided by the Item ending in " Ice Cream" (true for all 12 Recipes tools and all Menu ice creams, test-guarded). If Jack wants it explicit, `FromMenuItem` would need to carry a category or station (M1.3b scope).
- **Where to show a mistake with no row:** unwanted ice or sugar returns `Step = nil`. M1.5b needs a place for it (header or footer). Not decided here.

## Risks and notes for the UI lanes

- Row text in `Label` is a plain noun phrase ("Medium Clear Cup", "Normal Tapioca", "Steamed Milk"). Copy and casing are the UI lane's call.
- Stations that have no Recipes entry yet (known from the M1.3c notes: 8 Menu syrups, "Salted Hot Chocolate Powder", Latte, Oolong, 13 pastries) will produce a Station that no Model matches. `Steps` does not filter; M1.5c should tolerate a missing target Model.
- Wrong Item on a coffee: the card marks the Coffee Machine row only when the tool already has an Item with a size. A Clear Cup held for a coffee order is also shown there (the machine rejects it), and a Cup held for a boba order is shown on row 1.
- The Mug row is strict on Item == "Mug", so a cup in hand for a cocoa order is a Wrong Item on row 1 rather than a Close size.
- `Optional` is in the type per design 3.8 but unused; M1.5b can ignore it.
- The tree has unrelated untracked files from other lanes (`src/server/Modules/CustomerService/`, `CustomerService.spec.luau`, `CustomerConfig.luau`); not touched, and not in this change.
