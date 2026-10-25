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

## Extension: Espresso L7 + Mango L8

Approval: Jack, 2026-10-20 (DEC-057, "3. yes": Espresso L7 and Mango L8 join B1 phase 1). Depends on the `BIG-B1-P2-POOL.md` "Extension" (pool entries 6 Espresso and 7 Mango Boba); the builder does both in one run. Hot Cocoa Classic and Strawberry Tapioca stay OUT and get no pool entry, so they are never listed. Evidence: `.review/agent-workflow/tasks/REVIVAL-001/BIG-B1-P3-RECIPEBOOK/ext-espresso-mango/`.

### E1. How Taro/Strawberry were wired (verified in `git show ee9a515`)
- `Content.build(focusItem, level)` walks `CustomerConfig.ORDER_POOL`, dedupes by `entry.Key`, heads each block with `entry.Label`, puts `MinLevel > level` entries in `locked` (sorted by MinLevel, then pool index), and builds unlocked steps from `OrderSpec.Steps`. `init.luau` passes `Content.build(nil, level)` from the `Level` attribute.
- Everything is data-driven, so **`Content.luau` and `init.luau` need no edit**. The new entries appear automatically:
  - Espresso unlocked: `<b>Espresso</b>`, `1. Medium Cup`, `2. Espresso` (coffee branch with `Size = "Medium"`, Iced/Sugar false, so there are no Ice/Sugar rows).
  - Mango Boba unlocked: `<b>Mango Boba</b>`, `1. Medium Clear Cup`, `2. Milk`, `3. Mango Syrup`, `4. Normal Tapioca`.
  - Locked: `<font transparency="0.35"><b>Espresso</b>` + `\n` + `<font face="DenkOne">Unlocks at Level 7</font></font>`, and the same for `Mango Boba` with `Level 8`.
- Order at Level 1: three classics, then locked Taro Boba, Strawberry Boba (L2), Espresso (L7), Mango Boba (L8). At Level 2-6: five unlocked, then locked Espresso and Mango Boba. At Level 7: six unlocked, then locked Mango Boba. At Level 8+: all seven unlocked in pool order.

### E2. Exact edit: `src/server/Tests/RecipeBookContent.spec.luau` (the only file)
- **Existing case that would fail, so change it:** `level 2 unlocks them` asserts `expect(find(text, "Unlocks at")).to.equal(nil)`, but at Level 2 Espresso and Mango Boba are now locked. Change that one line to `expect(find(text, "Unlocks at Level 2")).to.equal(nil)`. Leave its other two asserts and every other existing case unchanged; they still hold. (`level 1 locks the level-2 drinks` still counts exactly 2 `Unlocks at Level 2`; `focus keeps pool order` at level 2 is unaffected.)
- Append inside `describe("Content.build (B1)")`:
  - `level 1 lists Espresso and Mango Boba locked, in level order`: `text = Content.build(nil, 1)`; `count(text, "Unlocks at Level 7")` is 1 and `count(text, "Unlocks at Level 8")` is 1; find indices satisfy `<b>Strawberry Boba</b>` < `<b>Espresso</b>` < `<b>Mango Boba</b>`; `find(text, "Mango Syrup")` is nil.
  - `level 7 unlocks Espresso only`: `text = Content.build(nil, 7)`; contains `2. Espresso`; `count(text, "Unlocks at")` is 1; contains `Unlocks at Level 8`.
  - `level 8 unlocks everything`: `text = Content.build(nil, 8)`; contains `2. Espresso` and `3. Mango Syrup`; `find(text, "Unlocks at")` is nil; find index `<b>Strawberry Boba</b>` < `<b>Espresso</b>` < `<b>Mango Boba</b>` (pool order).
- Use the file's existing `find` / `count` helpers (plain `string.find`).

**Not touched:** `Content.luau`, `init.luau`, `CustomerConfig.luau` (owned by the P2 extension), Styles, and `src/server/Scripts/ActivityScript.server.luau`. There is no new token, Instance or string pattern (DEC-013).

### E3. Gate
- `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Tests/RecipeBookContent.spec.luau'`.
- The same by hand: `selene src/server/Tests/RecipeBookContent.spec.luau`; `stylua --check src/server/Tests/RecipeBookContent.spec.luau`; `rojo build default.project.json -o <scratchpad>/b1ext-rb.rbxl` (outside the repo).
- TestEZ in Studio with `TESTS_ENABLED = true` in `src/server/Tests/RunTests.server.luau` (revert before finishing); RecipeBookContent and CustomerService specs pass.

### E4. Studio checks (Jack)
- S-RB-EXT-1: at Level 1, open the Recipe Book. Expected: dimmed `Espresso` / `Unlocks at Level 7` and `Mango Boba` / `Unlocks at Level 8` below the dimmed L2 drinks; the list scrolls at 844x390 and nothing is clipped.
- S-RB-EXT-2: keep the book open through the Level 6 -> 7 level-up. Expected: Espresso turns full white with 2 steps (`1. Medium Cup`, `2. Espresso`); Mango Boba stays locked.
- S-RB-EXT-3: at Level 8. Expected: no `Unlocks at` text; Mango Boba shows 4 steps ending `4. Normal Tapioca`.
- Place content: none beyond the P2 extension's S-EXT-1/S-EXT-3 (the book is text only).

### E5. Acceptance
- At Level 1 the book has 4 locked blocks in order Taro, Strawberry, Espresso, Mango Boba; at Level 7, 1 locked block (Mango Boba); at Level 8, none.
- All RecipeBookContent cases pass (one assert narrowed as in E2).
- The gate passes with no new findings in the spec file.

### E-Open items
- None for Jack. The pool weights are PENDING JACK under the P2 extension (E-O2).
