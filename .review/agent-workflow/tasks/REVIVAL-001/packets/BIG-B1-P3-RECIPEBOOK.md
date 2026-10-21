---
id: BIG-B1-P3-RECIPEBOOK
title: B1 phase 3 - Recipe Book shows one block per drink and a locked "Unlocks at Level N" state
priority: P0
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [BIG-B1-P2-POOL, TICKET-RECIPE-LINK]
status: READY
source_commit: 098175c
read_scope:
  - src/shared/UI/Pages/Recipes/Content.luau (Content.build, as left by TICKET-RECIPE-LINK)
  - src/shared/UI/Pages/Recipes/init.luau (component body, Label Text line)
  - src/shared/Configuration/CustomerConfig.luau (ORDER_POOL with Key/Label from BIG-B1-P2-POOL)
  - src/shared/Ordering/OrderSpec.luau (FromOrderItem, Steps)
  - docs/STYLE.md (3.3 PromptButton disabled text 0.35)
write_scope:
  - src/shared/UI/Pages/Recipes/Content.luau (Content.build only)
  - src/shared/UI/Pages/Recipes/init.luau (level state + the Content.build call only)
  - NEW src/server/Tests/RecipeBookContent.spec.luau
invariants:
  - DEC-013 / STYLE rule 0: no new Instance, colour, font, radius, spring or layout; the locked look is RichText inside the existing Label using the STYLE 3.3 disabled-text transparency 0.35
  - serve-path no-yield: not applicable (client UI and a pure string builder)
  - Content.build stays pure (no Instances, no services beyond the requires it has)
  - only ORDER_POOL entries appear; drinks without a pool entry (Hot Cocoa Classic, Strawberry Tapioca) are never listed
acceptance:
  - at Level 1 the book lists the three classics with steps, then Taro Boba and Strawberry Boba as locked blocks reading "Unlocks at Level 2" with no steps
  - at Level 2 all five blocks show steps; no "Unlocks at" text
  - the Level attribute changing while the page is open re-renders the book
  - TICKET-RECIPE-LINK focus still works: focus "Custom Boba" lists the unlocked boba blocks first, in pool order
  - gate passes with no new findings in the three files
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/shared/UI/Pages/Recipes/Content.luau src/shared/UI/Pages/Recipes/init.luau src/server/Tests/RecipeBookContent.spec.luau'"
  - rojo build default.project.json -o <scratchpad>/b1p3.rbxl
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P3-RECIPEBOOK
forbidden: [WORKER-PRIMER 8, any new Styles token or Instance, editing Content.Tips, editing CustomerConfig.luau, editing the page geometry or TopBar, listing items not in ORDER_POOL]
---

Worker rules: `_meta/WORKER-PRIMER.md`. Design: `packets/BIG-B1.md` section 7. Source commit 098175c.

## 1. Source excerpt (verbatim from `_meta/excerpts`)
- B1: The Recipe Book shows locked drinks with "Unlocks at Level N". Dependencies: ... a Recipe Book locked state (a new visual, Jack).
- INVENTORY: B1 Recipe Book "locked" look is a new visual: Opus builds it from existing tokens only (DEC-053).

## 2. Decisions made
- D1 One block per ORDER_POOL entry, deduped by `Key` (today: by `Item`, which collapses every Custom Boba into one). Header is the entry `Label`. Rationale: Taro and Strawberry Boba differ only in the syrup step, which is the thing to learn.
- D2 An entry is locked when `entry.MinLevel > level`. Locked block = header plus one line `Unlocks at Level {MinLevel}`, no steps, the whole block wrapped in `<font transparency="0.35">`. Rationale: 0.35 is the existing disabled-text value (STYLE 3.3 PromptButton); no new visual element.
- D3 Order: focused unlocked blocks (pool order), then other unlocked blocks (pool order), then locked blocks by MinLevel ascending, pool order within a level. Rationale: what you can make now comes first; the next goal sits at the bottom as the ladder.
- D4 Focus (TICKET-RECIPE-LINK) matches `orderItem.Item == focusItem` on unlocked blocks only; locked blocks are never moved up. This replaces TICKET-RECIPE-LINK's `table.insert(blocks, 1, block)`, which would reverse the boba blocks. Rationale: the ticket passes `item.Item` only and keeps its signature.
- D5 `level` comes from `Players.LocalPlayer:GetAttribute("Level")` (ProgressionService `setAttributes`); a non-number reads as 1. The page subscribes with `GetAttributeChangedSignal("Level")` and disconnects on unmount.
- D6 Steps text is unchanged: `<font face="DenkOne">{i}. {row.Label}</font>` from `OrderSpec.Steps`; Grab items keep `Grab it from the display.`. Rationale: book text stays generated, never hand-written.

## 3. Exact strings
- Unlocked header: `<b>{Label}</b>`; step line unchanged.
- Locked block (one string, `\n` between the lines):
  `<font transparency="0.35"><b>{Label}</b>` + `\n` + `<font face="DenkOne">Unlocks at Level {MinLevel}</font></font>`
- Blocks joined with `\n\n` (unchanged).
- At Level 1 the last two blocks read `Taro Boba` / `Unlocks at Level 2` and `Strawberry Boba` / `Unlocks at Level 2`.

## 4. Exact numbers
- `LOCKED_TRANSPARENCY = 0.35` (local in Content.luau, comment `-- STYLE 3.3 disabled text`).
- Default level 1. Sized entries render with `Size = "Medium"` (unchanged).

## 5. Signatures and event names
- `function Content.build(focusItem: string?, level: number?): string` (adds `level`; `nil` -> 1).
- Build three local lists `focused`, `unlocked`, `locked` (locked items carry `MinLevel` and pool index); `table.sort(locked, function(a, b) return if a.MinLevel ~= b.MinLevel then a.MinLevel < b.MinLevel else a.Index < b.Index end)`; concat `focused`, `unlocked`, `locked` block strings.
- Dedupe key: `entry.Key or orderItem.Item`; header text: `entry.Label or orderItem.Item`.
- init.luau, top of the component after `local px = usePx()`:
  - `local player = Players.LocalPlayer`
  - `local function readLevel(): number local value = player and player:GetAttribute("Level") return if typeof(value) == "number" then value else 1 end`
  - `local level, setLevel = React.useState(readLevel)`
  - `React.useEffect(function() if player == nil then return nil end local connection = player:GetAttributeChangedSignal("Level"):Connect(function() setLevel(readLevel()) end) return function() connection:Disconnect() end end, {})`
  - Text line: `Text = if isRecipes then Content.build(focusItem, level) else Content.Tips,`
- No remote, attribute write or profile field.

## 6. UI spec
- Surface unchanged: Staff Guide card (ROSE_MID fill, OFFWHITE 3.5 stroke, CORNER_CARD, AspectRatio 0.75) and its single RichText Label (FONT_FREDOKA, OFFWHITE, `px(35)`, TextWrapped, AutomaticSize Y in the ROSE_DEEP-scrollbar ScrollingFrame).
- Unlocked: OFFWHITE text, bold header, DenkOne steps. Locked: same text at 0.35 transparency, 2 lines.
- States: Level 1 (2 locked), Level >= 2 (none locked), focus from a ticket tap.
- Phone 844x390: usePx floors at 0.75, so text is about 26 px; at Level 1 the book is 5 blocks (about 20 lines) and scrolls in the existing frame. No layout change.

## 7. Spec cases (NEW src/server/Tests/RecipeBookContent.spec.luau)
Header comment as the other specs; `local Content = require(ReplicatedStorage.Shared.UI.Pages.Recipes.Content)`.
- `level 1 locks the level-2 drinks`: `Content.build(nil, 1)` contains `Unlocks at Level 2` twice and `<b>Taro Boba</b>`, and does not contain `Taro Syrup`.
- `level 2 unlocks them`: `Content.build(nil, 2)` contains `3. Taro Syrup` and `3. Strawberry Syrup`, and no `Unlocks at`.
- `nil level reads as 1`: `Content.build()` equals `Content.build(nil, 1)`.
- `locked blocks come last`: at level 1, `string.find` index of `Fudge Brownie` < index of `Taro Boba`.
- `focus keeps pool order`: `Content.build("Custom Boba", 2)` starts with `<b>Classic Milk Tea Boba</b>`, and `Taro Boba` < `Strawberry Boba` < `Regular Coffee` by find index.
- `grab text stays`: output contains `Grab it from the display.`.
Use `string.find(s, pattern, 1, true)` (plain) for every check.

## 8. Studio checks (Jack; one milestone run)
- S-RB1: Level 1, open the Recipe Book. Expected: Classic Milk Tea Boba, Regular Coffee, Fudge Brownie with steps; then dimmed Taro Boba and Strawberry Boba, each with `Unlocks at Level 2`.
- S-RB2: Keep the book open while reaching Level 2. Expected: the two blocks turn full white and show 4 steps each, no reopen needed.
- S-RB3: Level 2, tap a boba order name on the ticket. Expected: the book opens with the boba blocks first, Classic before Taro before Strawberry.
- S-RB4: Device emulator 844x390. Expected: locked lines readable, nothing clipped horizontally, the list scrolls.

## 9. Asset prerequisites
- None (text only, existing page).

Open items:
- NOTE: Hot Chocolate (L3) and Strawberry Pearl Boba (L4) appear in the book automatically once the BIG-B1-P2-POOL follow-up adds their pool entries after Jack's HARD-STOP 1 answers; no change here.

## Summary
- Recipe Book lists one block per pool drink, headed by its Label.
- Drinks above the player's Level show dimmed `Unlocks at Level N` (STYLE 3.3 disabled-text 0.35), no steps, at the bottom.
- Live update on the Level attribute; TICKET-RECIPE-LINK focus keeps pool order.
- Text-only change inside the existing Label: no new token, Instance or layout.
- New pure spec for Content.build.
