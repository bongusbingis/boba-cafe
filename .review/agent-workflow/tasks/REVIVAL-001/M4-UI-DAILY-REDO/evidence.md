# M4-UI-DAILY-REDO evidence (Part A, Mason)

Answers: Q16=A, Q17=A (no dim), Q18=A (DEC-041). Part B (Studio captures) not done.

## Files
- Changed: `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (logic verbatim; split into outer `Page` shell + inner `DailyRewardsMenu`; render replaced by `OpenableMenu` with one "Rewards" tab: title, hint, 7 `ShopItem` rows, `PromptButton`; Backdrop and custom close removed).
- Added: `src/shared/UI/Pages/Quests/init.luau`, `src/shared/UI/Pages/Quests/DailyQuests.luau`, `src/shared/UI/Stories/DailyRewards.story.luau`, `src/shared/UI/Stories/Quests.story.luau`.
- Changed: `Hud/init.luau` (QuestCard removed), `Hud/BottomLeft.luau` (Quests button order 4, Points 5, Bucks 6).
- Deleted: `src/shared/UI/Components/Core/Hud/QuestCard.luau`.

## Gate
All 7 changed/added files: Selene new=0, StyLua ok; rojo build ok; GATE: PASS. (BottomLeft baseline 1 finding, unchanged.) First run flagged 2 new warnings in the dialog (unused `isLocked`, `UDim2.new` scale-only); fixed.

## Deviations
- Progress-bar label `TextStrokeColor3` was literal `Color3.fromRGB(40,40,40)`; now `Color3.new(0,0,0)` (black text outline, STYLE 1.7) to satisfy the no-literal-fromRGB constraint. Slightly darker outline.
- `isLocked` removed (unused; locked rows are the GRAY default).
- Story quest rewards (40 BB / 25 XP) are hand-typed mock values, story only.
- Daily row labels use ShopItem's existing scaled label; long labels (day 4/7 plus "Claim now!") shrink: Jack should check legibility.

## New visual elements
None. Existing token / new combination for Jack: lone side tab "Rewards" on OpenableMenu, the "✓" text, GOLD_MID current row.

## Test for Jack (Play)
- Join with a claim available: Daily opens by itself as a menu; close with X; no screen dim; Shop and Daily look like one family.
- Daily button: opens menu; claim Day N; toast and amounts match (30/45/60/60/90/120/180, x2 VIP); button turns to disabled countdown; dialog does not re-bounce every second.
- Quests button next to Daily opens the Quests menu; pressing again closes it; no HUD quest card on screen.
- Quests: progress, Claim, Claimed, 20 BB reroll (Free with pass), "Not enough Boba Bucks" toast when broke; empty state "You don't have any quests!".
- Mobile: device emulator landscape and portrait; text legibility; taller bottom-left column.
- Note: nothing now signals a claimable quest or daily reward (indicator is a separate ask).

---

# Part B (Lens, Sonnet): Studio captures
Studio "jacks project" (89999123284040), Edit mode only (get_studio_state = Edit). No Play, no TestEZ, no script edits, nothing saved. Viewport 1173x864.

## Source freshness
Studio ALREADY held the Part A source (not stale). djb2 (CR stripped) + length checked for every script under `ReplicatedStorage.Shared` vs repo `src/shared`: the 5 changed/new modules (DailyRewardsDialog, Pages/Quests, Pages/Quests/DailyQuests, Hud/init, BottomLeft) and all dependencies used (Styles, Pane, PageTitle, SideButtons, Page, OpenableMenu, NormalButton, HudTabButton, ShopItem, CloseButton, PromptButton, SmallNotification, usePx, GamepassUtil, RankUtil, WorldPath, DailyRewardConfig, QuestConfig) are identical. `QuestCard` absent in Studio. Because Studio's require cache could hold old modules, each run required a `:Clone()` of the Studio module parented under the temporary gui (clone includes DailyQuests child; BottomLeft cloned beside a SmallNotification clone in a `Hud` folder). Cloned Source is hash-identical to repo text.

## Mounts
- Daily (a-c): ScreenGui named `Priority`, DisplayOrder 100, ResetOnSpawn false, ZIndexBehavior Sibling, IgnoreGuiInset false; dialog rendered directly (wraps its own Page). `Status` built from `DailyRewardConfig.REWARDS[DayToClaim]`; OnClose/OnResolution no-ops.
- Quests (d): ScreenGui `_LensPreview`, Sibling, IgnoreGuiInset true, ResetOnSpawn false; `Pane(full) > Pages > Page > Quests`. Quests entries from `QuestConfig.TEMPLATES` (BobaOrdered idx2 target 5 progress 1; CustomersServed idx2 target 10 done; SpillsCleaned idx2 target 4 claimed), rewards from template.
- BottomLeft (e): same gui, `Pane(full)` with BottomLeft sibling, `CurrentPage=nil`, `SetCurrentPage=noop`.
Springs do not advance in edit mode (panel frozen at its starting UIScale); real size in Play is larger. The countdown effect did run (c shows 11:59:57 after 1.2 s).

## Captures (captures/)
- a-daily-day3-canclaim.jpg: 30/45/60/60/90/120/180; Day 1-2 green "✓", Day 3 gold "- Claim now!", Day 4-7 gray; Day 4 "+ Regular Capsule", Day 7 "+ Rare Capsule"; green "Claim Day 3 Reward".
- b-daily-day3-vip.jpg: 60/90/120/120/180/240/360, hint ends "• 2x VIP".
- c-daily-claimed.jpg: Day 1-3 "✓", disabled grey "Next in 11:59:57", hint "Next reward in ...".
- d-quests-menu.jpg: "Quests" title tab, side tab "Daily Quests", three rows: 1/5 with "20 BB" reroll, 10/10 "Claim", 4/4 "Claimed"; pills +40 BB/+25 XP, +40/+25, +30/+20 (config-derived).
- e-bottomleft-daily-quests.jpg: column Clock Out, Recipe Book, Daily (gold, bucks icon), Quests (green, text only), Points, Bucks. Bottom of column is at screen edge, no collision with anything (nothing else mounted).

## Per-capture checks
Dialog panel on screen about 745x545 px (x 214-959, y 157-707, close X included) in the 1173x864 viewport; Quests identical frame. No dim and no overlay in any capture; nothing draws over the panel (backdrop bug gone: whole screen un-dimmed, panel fully bright). Frame matches M4-UI-REF 01/04: title tab top-left, red X top-right, green border, faint pattern, side tab column on left (one tab, selected outline), Fredoka text.

## Legibility
- Day 4 and Day 7 rows: full text "Day 4: 60 Boba Bucks + Regular Capsule" and "Day 7: 180 Boba Bucks + Rare Capsule" fit on one line with margin, legible white-on-gray; same text size as the other rows (no shrink visible). VIP: "Day 7: 360 Boba Bucks + Rare Capsule" also fits. Row labels are small (about 14 px at this size) and white on GRAY rows has low contrast; gold "Day 3 ... Claim now!" row is readable.
- Hint line (GRAY on white) is light; VIP hint nearly fills the width.
- Quests: row titles (~11 px), reward pills (~9 px) and progress labels (~9 px) are small and tight; "20 BB" is gold-on-gold button text with weak contrast. Rows leave the lower 40% of the menu empty. Flag for Jack.
- Day rows do not have a per-day icon; the lone "Rewards" tab column is mostly empty green.

## Elements not from existing tokens/components
None found. "Existing token, new combination" for Jack: lone side tab (Rewards / Daily Quests), "✓" text, GOLD_MID current row, text-only Quests NormalButton.

## Cleanup
After the last run: `_LensPreview` nil, `Priority` nil, StarterGui children 1 (UIArchive), ReplicatedStorage children 7, same as before; `_G.LensRoot/LensGui` cleared. Not saved. Not captured: `d2-quests-empty` (needs IsRunning), Play-only behaviour (pop-in spring, re-bounce check).
