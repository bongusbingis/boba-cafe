# M2-RECIPEBOOK: Recipe Book replaces the rank-gated Staff Guide
Model: sonnet   Studio: no   Depends on: M2-SHIFT (both edit BottomLeft.luau; run after it)   Size: M

## Goal
The old "Staff Guide" page (about ranks and Staff Points) is replaced by a "Recipe Book" listing, for each item NPCs order, the steps to make it. The text is generated from `OrderSpec.Steps` so it never goes stale. Settled by design §9 M2 outline and DEC-002.

## Read (only these)
- `src/shared/UI/Pages/Recipes/init.luau` (whole; 165 lines) and `Content.luau` (whole; 38 lines)
- `src/shared/Ordering/OrderSpec.luau` lines 40-75 (types, `Step`) and 525-570 (`OrderSpec.Steps`, `FromOrderItem`)
- `src/shared/Configuration/CustomerConfig.luau` (`ORDER_POOL`)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` lines 306-360 (Staff Guide button)
- `docs/STYLE.md` lines 446-460 (4.1 incl. the stand-alone page model) and 564-577 (copy rules)

## Write scope
- `src/shared/UI/Pages/Recipes/Content.luau`
- `src/shared/UI/Pages/Recipes/init.luau` (tab names and text source only)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (button text only)
- `src/shared/UI/Stories/Recipes.story.luau` only if it exists (grep first)

## Steps
1. **Content.luau.** Replace the static rank text with a function `Content.build() -> string` returning RichText. For each entry in `CustomerConfig.ORDER_POOL` (deduplicated by `Item`): `spec = OrderSpec.FromOrderItem(entry)`, `rows = OrderSpec.Steps(spec)`; output a line `<b>Item name</b>` then one numbered line per row, using the row's label field exactly as `OrderSpec.Steps` returns it (read the `Step` type at lines 40-75 for the field name). Use `<font face="DenkOne">` for step lines exactly as the old file did, and the same line structure (STYLE 4.1 stand-alone page). Items whose `Steps` returns `{}` print "Grab it from the display." Keep the page's tab structure: tab 1 "Recipes" (the generated text), tab 2 "Tips" with three fixed lines: "Clock in to use the kitchen.", "Match the size and flavor on the ticket.", "Perfect drinks pay the most." (sentence case per STYLE 7).
2. **init.luau.** The two top tabs become "Recipes" and "Tips" (Title Case, STYLE 7). Colours, sizes, strokes and the scroller stay as they are (DEC-013). Nothing about ranks or Staff Points remains in the page.
3. **BottomLeft.luau.** The button `Text = "Staff Guide"` becomes `"Recipe Book"`. Nothing else changes (LayoutOrder, colour, handler).
4. The page needs no rank: it already opens for everyone via the button. Confirm with grep that no rank check gates it (`RankUtil` in BottomLeft only gates the admin shift timer button; leave that).
5. `stylua` then `gate` on all changed files.

## Done when
- The page lists every `ORDER_POOL` item with its steps from `OrderSpec.Steps`, no hard-coded recipe text.
- No text about ranks or Staff Points remains in `Content.luau`.
- Button reads "Recipe Book".
- Gate passes on all changed files.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN (Jack tests: open the Recipe Book, scroll, check each item).

## STOP-AND-ASK
- `Steps` rows lack a text label field: ask Jack for the wording per step type.
- Staff Points still exist (the Points currency and the group promotion text): the old page documented the group promotion. If Jack wants that text kept elsewhere, ask where.
- The Tips tab copy is a placeholder from this packet; ask Jack to confirm the three lines.

## Evidence
`tasks/REVIVAL-001/M2-RECIPEBOOK/evidence.md` (RUNBOOK step 5).
