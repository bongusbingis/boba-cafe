# Q14-GATES: Attribute station gates, faster holds, ice/sugar in any order
Model: sonnet   Studio: no   Depends on: R1-FIX (it edits `Recipes.luau`, `RecipeConstructors.luau` for P3-6)   Size: M

## Goal
Players can add ice and sugar in either order, and the Coffee and Ice machines are faster. Settled by DEC-011 (Q14), design §3.2 and §3.3.

## Read (only these)
- `M1.2/design.md` lines 108-125 and 138-139 (§3.2 holds, ice-before-sugar)
- `R1/review.md` line 40 (finding 5) and line 42 (finding 6)
- `src/shared/Kitchen/Recipes.luau` lines 186-262 (Coffee Machine, Sugar, Ice Machine) and lines 126-135 (Sink gate)
- `src/shared/Kitchen/RecipeConstructors.luau` lines 78-90 (`makeCoffeeVariant`) and 228-240 (`getCoffeeNames`)
- `src/server/Modules/KitchenService/Actions/ToolNameValidityCheck.luau` (whole) and `SetToolAttributes.luau` (whole)
- `src/shared/Ordering/OrderSpec.luau` lines 215-340 (`StepState` ice/sugar rows)
- `src/server/Tests/OrderSpec.spec.luau` lines 735-770; `src/server/Tests/KitchenAttributes.spec.luau` (only where it names Coffee Machine, Ice Machine or Sugar)

## Write scope
- `src/shared/Kitchen/Recipes.luau`
- `src/shared/Kitchen/RecipeConstructors.luau`
- `src/server/Modules/KitchenService/Actions/ToolNameValidityCheck.luau` (only if a new attribute-check mode is needed; see step 1)
- `src/shared/Ordering/OrderSpec.luau` (`StepState` only)
- `src/server/Tests/OrderSpec.spec.luau`, `src/server/Tests/KitchenAttributes.spec.luau`

## Steps
1. **Attribute gate.** `ToolNameValidityCheck` matches the tool name. Add a sibling action `ToolAttributeCheck` (new file `src/server/Modules/KitchenService/Actions/ToolAttributeCheck.luau`, same signature and failure behaviour as `ToolNameValidityCheck`; also add it to this write scope) taking a table of `{ attribute = expected }` where a string means the attribute must equal it (a string containing `|` means equal to any one of the listed values), `true` means must equal true, and `false` means must not be `true`. Register it the same way `ToolNameValidityCheck` is registered (grep the Actions loader).
2. **Entries to change (exact):**
   - `Recipes["Sugar"]` (line ~233): gate `{ "ToolNameValidityCheck", { "!Sugar" } }` becomes `{ "ToolAttributeCheck", { Item = "<coffee names joined with |>", Sugar = false } }`; build the Item string from `RecipeConstructors.getCoffeeNames()` joined with `|` at module load. Keep the rename `old .. " + Sugar"` and `SetToolAttributes { Sugar = true }`.
   - `Recipes["Ice Machine"]` (line ~248): gate becomes `ToolAttributeCheck` with the same Item list and `Iced = false`, (an empty cup has `Item = "Cup"`, so the Item list already refuses it). Keep `Iced = true` write and the "Iced " rename.
   - `Recipes["Coffee Machine"]` (line ~190): `HoldDuration = 7` becomes `4`. `Recipes["Ice Machine"]`: `HoldDuration = 5` becomes `3`. Add `-- TUNING (Q14)` to both lines.
   - `Recipes["Sink"]` gate `#Cup|!Milk` (line ~130): leave as it is (design §3.3: Sink is Q22, not here).
3. **Spec P3-5.** In `OrderSpec.StepState` (lines ~224-241 and ~301-333), when the spec wants ice and the tool has `Sugar == true` and `Iced ~= true`, there is no longer a blocked state: ice is still the current row (the gate now accepts it). Change `OrderSpec.spec.luau` case "sugar before ice leaves ice current" (line ~757) to describe the kitchen truth: name it "sugar before ice is allowed; ice is still current" and keep the expected row 3. If Match grades a finished-but-wrong-order tool, nothing else changes. Add one case: `{Item=Regular, Size=Small, Iced=true}` with the spec wanting sugar leaves sugar current.
4. Update `KitchenAttributes.spec.luau` only where it hard-codes the old gate strings or hold values.
5. `stylua` then `gate` on all changed files.

## Done when
- The gate passes (RUNBOOK step 3).
- `grep -n "HoldDuration" src/shared/Kitchen/Recipes.luau` shows Coffee Machine 4 and Ice Machine 3.
- Sugar and Ice recipe entries contain no name-pattern gate on `Sugar` or `Iced`.
- Studio behaviour is UNVERIFIED for M1.6.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN.

## STOP-AND-ASK
- The Actions loader cannot register a new action without editing a file outside the write scope: name the file and ask.

## Evidence
`tasks/REVIVAL-001/Q14-GATES/evidence.md` (add Gauge steps for M1.6: coffee, sugar then ice, ice then sugar; each must produce the same finished tool).
