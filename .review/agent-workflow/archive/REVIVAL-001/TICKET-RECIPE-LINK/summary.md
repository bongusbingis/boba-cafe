# TICKET-RECIPE-LINK (T8 half) — evidence summary

## Scope executed
- T4 "Fast bonus!" cue verified present at `RecipeCard.luau:121` (from commit 676b2dc). RecipeCard NOT touched.
- Implemented packet sections 5–6 link plumbing only (T8 half).

## Changes
- `src/shared/UI/Components/Core/Hud/OrderTicket.luau`: ItemRow name `TextLabel` → `TextButton`
  (identical look, `AutoButtonColor = false`, `Active` iff handler exists, `[React.Event.Activated]`);
  `ItemRow` props + `onOpenRecipe`; `OrderTicket` props + `SetCurrentPage`;
  item loop passes `onOpenRecipe` calling `props.SetCurrentPage(UI.Pages.Recipes, item.Item)`.
- `src/shared/UI/Components/Core/Hud/init.luau`: exactly two prop lines —
  `SetCurrentPage = props.SetCurrentPage` on both `c(OrderTicket, ...)` calls. Nothing else touched.
- `src/shared/UI/Pages/Recipes/init.luau`: `local focusItem = ... props.Args[1] ...`;
  Text line now `Content.build(focusItem, level)` (level arg kept; packet predates the level param).
- `src/shared/UI/Pages/Recipes/Content.luau`: NO edit — focus-first insert per D4 already
  present at HEAD (`orderItem.Item == focusItem` → focused blocks moved first, lines 22–24/65–68/78–84).

## Known limitation P3-9 (per packet D4, NOT redesigned)
- Focus key is the Menu key `item.Item` (e.g. `"Custom Boba"`); ALL blocks sharing that key focus
  together. Implemented exactly as specified; flagged, no redesign attempted.

## Forbidden-zone compliance
- Untouched: CustomerConfig.luau, App.luau, all server files, RecipeCard.luau, Hud/init beyond the
  two prop lines. No new Styles token. Did not read/touch `src/server/Scripts/ActivityScript.server.luau`.
- No commit, no push, no Studio/Play/TestEZ.

## Verification
- Gate (Selene + StyLua, no new findings) + rojo build: see `gate-output.txt`. GATE: PASS.
- One StyLua formatting fix applied (props-table layout in OrderTicket); no semantic change.
- Runtime checks S1–S5 are for Jack (Studio, DEC-019 — not run).
