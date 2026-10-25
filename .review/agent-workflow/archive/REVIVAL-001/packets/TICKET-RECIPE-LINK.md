---
id: TICKET-RECIPE-LINK
title: Fast bonus cue on the ticket recipe card; tap a ticket drink name to open its Recipe Book page
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: [GAMEPLAY-MOBILE-TICKET]
status: READY
source_commit: 098175c
read_scope: [src/shared/UI/Components/Core/Hud/RecipeCard.luau, src/shared/UI/Components/Core/Hud/OrderTicket.luau, src/shared/UI/Components/Core/Hud/init.luau, src/shared/UI/Pages/Recipes/init.luau, src/shared/UI/Pages/Recipes/Content.luau, src/shared/Configuration/CustomerConfig.luau]
write_scope: [src/shared/UI/Components/Core/Hud/RecipeCard.luau (RecipeCard sub-line only), src/shared/UI/Components/Core/Hud/OrderTicket.luau (ItemRow name, OrderTicket props and ItemRow call only), src/shared/UI/Components/Core/Hud/init.luau (the two OrderTicket instances only: one prop line each), src/shared/UI/Pages/Recipes/init.luau (focusItem and the Content.build call only), src/shared/UI/Pages/Recipes/Content.luau (Content.build only)]
invariants: [DEC-013 (existing tokens and components only), no yield anywhere new (client UI only, no serve path), no change to CustomerConfig values, no change to server files, no change to App.luau]
acceptance:
  - RecipeCard sub-line shows " · Fast bonus!" appended while patience >= CustomerConfig.FAST_FRACTION and the order is not complete.
  - Tapping the drink name row of an order item on the Order Ticket opens the Recipe Book page with that drink's block listed first.
  - Recipe Book opened from the BottomLeft button is unchanged (no focus).
  - No new Styles token, component, colour or font.
checks: [scripts/gate.sh on each changed file (Selene, StyLua --check, no new findings); rojo build default.project.json -o <path outside repo>]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/TICKET-RECIPE-LINK
forbidden: [WORKER-PRIMER 8, editing CustomerConfig.luau or any FAST_FRACTION value, editing App.luau, tapping the RecipeCard header or the NPC TicketLabel (not in scope), any edit to Hud/init.luau beyond the two prop lines, any new Styles token]
---

Worker rules: link `.review/agent-workflow/tasks/REVIVAL-001/packets/_meta/WORKER-PRIMER.md` (sections 1-10). Source commit 098175c.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- T4 (review, HEAD c77e20c): What: Fast-bonus cue: the ticket sub-line reads "1/4 · Fast bonus!" while patience >= FAST_FRACTION (0.5). Why: The 1.5x Fast multiplier is the biggest pay lever and nobody knows it exists. Files: RecipeCard.luau (copy), reads CustomerConfig.FAST_FRACTION. Effort: XS. Risk: Low. Tag: JACK (Q-G11).
- T8 (review, HEAD c77e20c): What: Recipe Book link from the ticket (tap the item name to open the page for that drink). Why: Mid-session lookup without hunting buttons. Files: OrderTicket.luau, Pages/Recipes. Effort: S. Risk: Low. Tag: JACK (new interaction).

## 2. Decisions made
- D1 Fast cue: `RecipeCard` appends `" · Fast bonus!"` to its existing `Sub` label when `typeof(props.patience) == "number"` and `props.patience >= CustomerConfig.FAST_FRACTION` and `current <= total`. Rationale: Q-G11 threshold is the same 50% the server uses for Fast (`Rules.luau` `fractionLeft >= c.FAST_FRACTION`); no bonus is shown after the order is complete because there is nothing left to speed up.
- D2 The cue is text only, inside the existing `Sub` TextLabel, colour unchanged (`Styles.GRAY`). Rationale: DEC-013, no new visual.
- D3 Tap target is the item name row inside `OrderTicket`'s `ItemRow` only. The RecipeCard header name and the NPC `TicketLabel` are not tappable. Rationale: smallest change that matches the review text.
- D4 The key sent to the Recipe Book is the order item's `item.Item` (the Menu key, e.g. `"Custom Boba"`). `Content.build` already compares `orderItem.Item` with the same string, so the match is exact and no variant text is parsed.
- D5 Navigation uses the existing App page mechanism: `props.SetCurrentPage(UI.Pages.Recipes, item.Item)`. The page reads `props.Args[1]`. The focused drink's block is inserted at the top of the list. No scroll measuring. If the key matches no block, the book is shown unchanged.
- D6 The item name changes from `TextLabel` to `TextButton` with identical props plus `AutoButtonColor = false` and `Active` set from whether a handler exists. Rationale: identical look, pattern already used by the ticket `Header` button.

## 3. Exact strings
- Fast cue suffix (leading space, middle dot U+00B7, exclamation): `" · Fast bonus!"`
- Sub line example at 0/4 with patience 60%: `"0/4 · Fast bonus!"`

## 4. Exact numbers
- Threshold: `CustomerConfig.FAST_FRACTION` (currently 0.5, DEC-024). Read it, never type 0.5.

## 5. Signatures and names
- `RecipeCard`: add `local CustomerConfig = require(Shared.Configuration.CustomerConfig)` directly after `local OrderSpec = require(Ordering.OrderSpec)`.
- `OrderTicket` props: `function(props: { stacked: boolean?, slot: number?, layoutOrder: number?, SetCurrentPage: ((page: any, ...any) -> ())? })`.
- `ItemRow` props: `{ item: { [string]: any }, layoutOrder: number, onOpenRecipe: (() -> ())? }`.
- `Content.build(focusItem: string?): string` (replaces `Content.build(): string`).
- `Hud/init.luau`: add `SetCurrentPage = props.SetCurrentPage,` to both `c(OrderTicket, {...})` calls (`OrderTicket` and `OrderTicket2`).
- `Pages/Recipes/init.luau`: add `local focusItem = if typeof(props.Args) == "table" then props.Args[1] else nil` at the top of the component; change the Text line to `Text = if isRecipes then Content.build(focusItem) else Content.Tips`.

## 6. Code shape
RecipeCard (after `local subText = ...` line, before `local rows = {}`):
```lua
if typeof(props.patience) == "number" and props.patience >= CustomerConfig.FAST_FRACTION and current <= total then
	subText ..= " · Fast bonus!"
end
```
OrderTicket, `ItemRow` name element becomes:
```lua
ItemName = c("TextButton", {
	LayoutOrder = 0,
	Active = props.onOpenRecipe ~= nil,
	AutoButtonColor = false,
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	FontFace = Styles.FONT_FREDOKA,
	Size = UDim2.new(1, -8, 0, 18),
	Text = name,
	TextColor3 = Styles.GREEN_DEEP,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	[React.Event.Activated] = props.onOpenRecipe,
}),
```
OrderTicket, in the item loop where `c(ItemRow, {...})` is created, add:
```lua
onOpenRecipe = if props.SetCurrentPage ~= nil and typeof(item.Item) == "string"
	then function()
		props.SetCurrentPage(UI.Pages.Recipes, item.Item)
	end
	else nil,
```
(`UI` is already a local in `OrderTicket.luau`.)

Content.build, replace the single `table.insert(blocks, table.concat(lines, "\n"))` with:
```lua
local block = table.concat(lines, "\n")
if typeof(focusItem) == "string" and orderItem.Item == focusItem then
	table.insert(blocks, 1, block)
else
	table.insert(blocks, block)
end
```

## 7. UI spec
- Ticket item name: unchanged position, size (1,-8) x 18, Fredoka 15, GREEN_DEEP, left aligned. No hover or press visual (AutoButtonColor false).
- Sub line: unchanged size (1,0) x 14, Fredoka 13, GRAY. Longer text stays on one line at 190 px ticket width scaled by TICKET_SCALE 1.6 (Hud/init.luau); if it does not fit it is clipped, not wrapped (same as today's Sub label). Report the 844x390 screenshot result in evidence.

## 8. Studio checks (batched by Prime for Jack; workers do not run Studio)
- S1: Clock in, take an NPC order, hold the matching tool with patience above 50 percent. Expected: the ticket sub-line reads `0/N · Fast bonus!`.
- S2: Let patience fall below 50 percent. Expected: the suffix disappears.
- S3: Tap the drink name row on the order ticket. Expected: Recipe Book opens with that drink's block first.
- S4: Open Recipe Book from the bottom-left button. Expected: list in the normal order, no focus.
- S5: On an 844x390 phone, repeat S3. Expected: the page opens and the ticket does not overlap the page.

## 9. Asset prerequisites
None. No sound, model or instance is required.

## 10. Lease note (Prime action)
`Hud/init.luau` is not in the INVENTORY lease row for TICKET-RECIPE-LINK. This packet writes only the two `OrderTicket` prop lines in it. HUD-LEVELBAR and SOUNDS also write `Hud/init.luau` and must run after this packet.

Open items: HARD-STOP none. LEASE: Prime to add TICKET-RECIPE-LINK to the `depends_on` of HUD-LEVELBAR (Hud/init.luau) and to note this packet's `Hud/init.luau` write in INVENTORY.

## Summary
- Adds a text-only "Fast bonus!" cue to RecipeCard at patience >= FAST_FRACTION while the order is open.
- Makes the ticket drink-name row tappable; it opens the Recipe Book with that drink listed first.
- Plumbs `SetCurrentPage` from Hud/init.luau into OrderTicket (two prop lines).
- Recipe Book `Content.build` takes an optional focus key; unchanged when absent.
- Client UI only; no server, economy, asset or serve-path change.
- Gate: Selene, StyLua, rojo build (worker runs). Runtime checks S1-S5 are for Jack.
