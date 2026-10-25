# M4-UI-DAILY-REDO: Rebuild the Daily Rewards dialog, add the Quests button and menu, retire the HUD quest card
Model: sonnet (Mason, Part A, Studio: no; Lens, Part B, Studio: YES exclusive)   Depends on: M4-UI-REF, M4-UI-APPROVAL, QUESTCARD-FIX, DEC-038, DEC-039, and Jack's answers to Q16-Q18 below   Size: M

## Goal
- Daily Rewards looks like the rest of the game (DEC-013, DEC-038 "sloppy, doesn't match"): rebuilt from existing components and patterns only, same data, same amounts (DEC-036), no economy change.
- The backdrop layering bug is gone.
- Quests leave the HUD (DEC-038, DEC-039 Q15=A): a Quests button next to Daily opens a Quests menu on an existing menu shell. Approved quest content (rows, reward pills, Claim/Reroll/Claimed, 20 BB reroll) is unchanged in behavior.
- One round of captures for Jack (Part B).

## PENDING JACK (Prime asks; Mason does not start Part A until the answers are recorded in decisions.md as DEC-041 and pasted into the "Jack's answers" block at the bottom of this file)
There is no single existing match for the Daily screen, so the shell is Jack's call. The evidence:
- `OpenableMenu` (M4-UI-REF 01, 04): title tab, red X, green border, faint pattern, side tabs. Used by Shop, Inventory and Menu, all opened from a HUD button. No backdrop. It has only ever been used with 3+ tabs.
- `ButtonPrompt` / `ActionPrompt` family (M4-UI-REF 02): small confirm panels, 200-440 px wide, 1-2 buttons. Too small for 7 reward days; enlarging the panel is a new size.
- The current Daily dialog imitates the `ActionPrompt` chrome (OFFWHITE panel, GREEN_DIM stroke, Banner) but adds its own close position, a literal `Color3.fromRGB(246,246,246)` card fill, a pill, and 8-14 px text, which is what read as sloppy (capture a-dialog-day3-canclaim.jpg).

**Q16 Shell and body for Daily** (Quests follows the same menu shell in options A, B, D; in C Quests still uses OpenableMenu):
- **A (recommended).** `OpenableMenu` with one side tab ("Rewards"), hosted as the same dialog type so the join auto-open keeps working. Body = the Shop's list look: a tab title, a hint line, then seven `ShopItem` rows (one per day, per-row token colour), then a `PromptButton` for Claim. Reason: everything on screen is an existing component (`OpenableMenu`, `ShopItem`, `PromptButton`), it matches Shop and Menu captures 01 and 04, it scales the same way, and rows keep text large. Cost: a lone side tab is a new combination (unverified look; Part B shows it) and the day cards become rows.
- B. `OpenableMenu` one tab, body = seven day cards in a grid keeping the current card content. Cards would need a card component; none shows icon + day + amount + state (`SelectionCard` has one label). That is a new composition and needs your OK.
- C. `ButtonPrompt` panel (9-slice + `Banner` + `PromptButton`) enlarged to fit the cards. New panel size and the same card problem as B.
- D. One merged "Daily" `OpenableMenu` with two side tabs, Rewards and Quests, both HUD buttons opening it (as Points and Bucks both open Shop). Best use of tabs, but it contradicts DEC-039 ("daily dialog stays its own screen"), needs new plumbing for the join auto-open, and re-pressing the other button closes instead of switching tab (`App.luau:36-43`).

**Q17 Dim behind the Daily screen:** none (recommended; no existing menu or `ButtonPrompt` dims, M4-UI-REF "Backdrop order per menu") or keep a dim (the `PromptSelection` / `CapsuleOpening` pattern, fix in Step 3).

**Q18 Quests button icon and colour.** Searched every icon id used in `BottomLeft`, `NormalButton`, `Menu.luau`, `Gamepasses.luau`, capsule/pet/particle definitions and `STYLE.md` 1.11: bucks 13382286492, points 13391365805, timer 8184068342, capsule 6073658218, generic pass 5893760810 and the rest. None depicts quests or a checklist.
- **A (recommended).** Text-only `NormalButton` with `Icon = ""`, exactly as Recipe Book does (`BottomLeft.luau:357-361`), `Color = Styles.GREEN_MID`, `Text = "Quests"`.
- B. You name an existing asset id (or supply a new asset; agents never create one).
- C. Reuse the bucks icon: not recommended, it would look identical to Daily.

## Already built (verified)
- Dialog: `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (props `Status`, `OffsetX`, `OnResolution`, `OnClose`, `Native`; status shape lines 93-105; handlers `handleClose` lines 158-168 and `handleClaim` 170-256; day logic 276-318). Its render is lines 320-593 and is what gets replaced. Opened by `src/client/Modules/DailyRewardController.luau:14-28` via `DialogController.new("DailyRewardsDialog", { Status })` (also auto-opens on join when `CanClaim`, lines 32-48) and by the Daily button at `BottomLeft.luau:368-382`.
- Backdrop bug (cause, in source): the `Backdrop` TextButton is `ZIndex = 50` and a sibling of `ModalPage` (a `Page` Pane at default ZIndex 1) under `ZIndexBehavior = Sibling` (`DailyRewardsDialog.luau:571-592`). The panel's own `ZIndex = 60` (line 486) is inside ModalPage, so it never beats the sibling. M4-UI-REF capture 05 shows it, and the real mount is the same: App gui and `Priority` gui both Sibling (`AppEntry.luau:22-26`, `AppDialogs.luau:252-256`; Priority leaves ZIndexBehavior default = Sibling), so it is not a preview artifact.
- Second defect found while reading: `Page` restarts its open spring whenever `props.PageContent` changes identity (`Page.luau:55-67`, deps `{ props.PageContent }`). The dialog keeps its countdown state in the same component that builds `PageContent`, so every 1 s countdown tick (and every claim state change) creates a new element and can replay the pop-in. Fixed structurally in Step 2. Springs do not advance in edit mode, so this can only be confirmed in Play by Jack (Test for Jack).
- Quest card: `src/shared/UI/Components/Core/Hud/QuestCard.luau` (props `Quests`, `Preview`; rows 170-322; fetch/claim/reroll logic 326-421; HUD chrome and header 427-547 incl. `ZIndex 10`, fixed 230 px width). Mounted only at `Hud/init.luau:18,68`. Fed by `Knit.GetService("QuestService")`: `GetQuests()`, `ClaimQuest(i)`, `RerollQuest(i)`, `QuestsUpdated`; no client controller sits between.
- Page registration pattern: `App.luau:29-59` renders any `ModuleScript` passed to `SetCurrentPage(page, ...)` inside `Page`, giving it `Args` and `ClosePage`; pressing the same HUD entry again closes it; `STYLE.md` 4.1. `Shop/init.luau:53-72` is the model (`OpenableMenu` + `OnClose = props.ClosePage`).
- Dialog host pattern: dialog modules are looked up by file name in `Components/Dialogs` (`AppDialogs.luau:154`); `CapsuleOpening` dialog wraps content in `Page` (STYLE 3.5).
- Daily button: `NormalButton`, `Icon "rbxassetid://13382286492"`, `Color GOLD_MID`, `LayoutOrder 3` (`BottomLeft.luau:368-382`). Points = 4, Bucks = 5.
- Verified in capture e-daily-button-bottomleft.jpg: column is Clock Out, Recipe Book, Daily, Points, Bucks. No quest or claim indicator exists.
- Nothing else references `QuestCard` (grep `src`: only `Hud/init.luau`). No spec covers the UI files.
- Existing empty-state copy pattern: `You don't have any <things>!` (STYLE 2.5, `InventoryComponent.luau:598-609`).

## Read (only these)
- `docs/STYLE.md` sections 0, 1.1-1.10, 2.1-2.5, 3.2, 3.3, 3.5, 4.1, 4.2, 9.14; `decisions.md` DEC-013, DEC-038, DEC-039 (and DEC-040 once written)
- `tasks/REVIVAL-001/M4-UI-REF/evidence.md` and its jpgs; `tasks/REVIVAL-001/M4-UI-APPROVAL/evidence.md` and its jpgs (the "before")
- `src/shared/UI/Components/Core/OpenableMenu.luau`, `Core/Page.luau`, `Pages/Shop/init.luau`, `Pages/Shop/Currency.luau` (tab title, scroller, category layout), `Pages/Shop/ShopCategory.luau:90-190` (header/footer ribbon, rows), `Components/Buttons/ShopItem.luau`, `Buttons/PromptButton.luau`, `Dialogs/ActionPrompt.luau:60-110` (px(50) button height), `Dialogs/CapsuleOpening.luau`
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (all), `Core/Hud/QuestCard.luau` (all), `Core/Hud/BottomLeft.luau:240-410`, `Core/Hud/init.luau`
- `src/client/Modules/DailyRewardController.luau`, `src/client/Modules/AppDialogs.luau:140-260`, `src/shared/UI/App.luau`
- `src/shared/Configuration/DailyRewardConfig.luau`, `QuestConfig.luau` (read only)
- `src/shared/UI/Hooks/usePx.luau`, `Stories/Shop.story.luau`

## Write scope
Part A (Mason):
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (render and structure only; logic stays)
- `src/shared/UI/Pages/Quests/init.luau` (new: OpenableMenu page)
- `src/shared/UI/Pages/Quests/DailyQuests.luau` (new: tab content, moved from QuestCard)
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (delete)
- `src/shared/UI/Components/Core/Hud/init.luau` (remove the QuestCard require and element)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (Quests button, renumber)
- `src/shared/UI/Stories/DailyRewards.story.luau`, `src/shared/UI/Stories/Quests.story.luau` (new, modelled on `Shop.story.luau`)
Part B (Lens): `tasks/REVIVAL-001/M4-UI-DAILY-REDO/` only (captures/, evidence.md). Studio: a temporary `StarterGui._LensPreview` ScreenGui, destroyed before finishing.
Not touched: `DailyRewardController`, any service, any Configuration file, `Styles.luau`, `OpenableMenu`, `Page`, `PromptButton`, `ShopItem`, `NormalButton`, `AppDialogs`, `AppEntry`, place-authored content (`workspace.Assets`, `Ordering System`, `SelectorModels`, `Networking`, `SoundService.SFX`).

## Hard constraints
- Never run Play or TestEZ (DEC-019). No Studio saves. Place-authored content is not edited.
- Gate on every changed or new Luau file: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. No new Selene/StyLua findings in changed files (baseline DEC-001). Run `rojo build default.project.json -o <path outside the repo>`.
- DEC-013 / STYLE section 0: only existing tokens, components, patterns. No new colour, radius, font, asset id, spring, shadow, gradient or component. No literal `Color3.fromRGB` (the current 246,246,246 card fill goes away). Text white on coloured rows, `GREEN` titles, `GRAY` hint (STYLE 1.4, 4.1a).
- Economy untouched: amounts come from `DailyRewardConfig.REWARDS[day].BobaBucks * (VIP_MULTIPLIER if IsVIP)`, reroll cost from `QuestConfig.REROLL_COST_BOBABUCKS`. Never hand-type an amount.
- Behavior unchanged: `Status` props and shape, claim flow and toasts, countdown refresh, `OnResolution("Close")`, `OnClose`, join auto-open, quest fetch/claim/reroll, free-reroll check, InsufficientFunds toast.
- `BuiltBy` attribute: not applicable (no Studio instances created).
- Do not add a claim-available or quest-complete indicator anywhere (new visual; see Evidence "Note for Jack").

## Steps (written for the recommended options: Q16 A, Q17 none, Q18 A. If Jack chose differently, Prime edits these steps before dispatch)
**1. Dialog structure.** In `DailyRewardsDialog.luau` keep the file's state, effects, `handleClaim`, `formatCountdown`, `playUiSound` verbatim. Split into two components so `Page` stops re-animating:
   - Inner `DailyRewardsMenu(props: { Status, OnClose, ... })`: everything that holds state or the countdown (current function body from `closeFnRef` onward, minus the `Page` wrap). It returns `c(OpenableMenu, ...)` (Step 2). Its `OnClose` is `props.OnCloseRequested`.
   - Outer exported function: owns `closeFnRef`, defines `handleClose` (call `closeFnRef.current()`, then `props.OnResolution("Close")`, then `props.OnClose()`, same order as today), and returns `c(Page, { IsVisible = true, PageContent = c(DailyRewardsMenu, { Status = props.Status, OnCloseRequested = handleClose }), OnClosing = function(cb) closeFnRef.current = cb end })`. Same shell as `ButtonPrompt.luau:37-43,137` (STYLE 4.2). The outer component holds no countdown state, so it does not re-render each second.
   - Keep `OffsetX` and `Native` in the exported prop type; ignore them (menus do not use `OffsetX`).
**2. Menu content (Q16 A).** `c(OpenableMenu, { TitleText = "Daily Rewards", TitleColor = Styles.GREEN, Pages = { { Key = "Rewards", Label = "Rewards", Content = rewardsTab } }, OnClose = props.OnCloseRequested })`. `rewardsTab` is a full-size transparent Frame built like `Currency.luau:33-85` (STYLE 4.1a, 2.5):
   - `Title` TextLabel: text `7-Day Rewards`, Position (0.470149,0), Size (0.94,0.09), `GREEN`, Fredoka, scaled.
   - Hint line: Position (0.5,0.095), Size (0.94,0.085), `Styles.GRAY`, scaled (`Pets.luau:112-121`). Text = the existing `subtitleText` string unchanged; when `isVIP`, append ` • 2x VIP` (replaces the gold pill, no pill is built).
   - Scrolling list (STYLE 2.5 defaults) holding seven `ShopItem` rows, `LayoutOrder = day`, no `Price`, so no glyph. Label = `Day {n}: {bucksAmount} Boba Bucks` plus ` + Regular Capsule` (day 4) / ` + Rare Capsule` (day 7) using the existing `capsuleName` rule; prefix `✓ ` when claimed (existing copy `✓ Claimed`) and suffix ` - Claim now!` on the current day. Row `Color`: claimed `Styles.GREEN_LIGHT`, current `Styles.GOLD_MID`, locked `Styles.GRAY`. Only the current claimable row gets `OnClick = handleClaim`. Status logic (`isClaimed`, `isCurrent`, `isLocked`) is copied unchanged.
   - Below the list, a Frame of height `px(50)` (`usePx`, ActionPrompt precedent) with the existing `PromptButton`: claimable = `Text "Claim Day {dayToClaim} Reward"`, `Color Styles.GREEN`, `OnClick handleClaim`; else `Disabled = true`, `Color Styles.GRAY`, text `Next in {formatCountdown}` or `All Claimed!`, exactly as the current bottom bar.
   - Delete: `Banner` header, custom `CloseButton`, `UISizeConstraint`, `BUCKS_ICON`/capsule icon constants, day-card Panes, VIP pill, `ZIndex = 60` panel.
**3. Backdrop (Q17 none).** Delete the `Backdrop` element and the wrapping full-size Frame. Reason: no existing menu, `ButtonPrompt` or `ActionPrompt` dims (M4-UI-REF "Backdrop order per menu"), so the shell chosen has none; this removes the bug rather than reordering it, and `Priority`'s inset (STYLE 2.3) no longer needs compensating. Click-away close is gone; close is the red X, as in every other menu. (If Jack chose to keep a dim: keep one `Backdrop` as the first child of the outer Frame, `ZIndex = 0`, below `ModalPage` at its default `ZIndex 1`, the `CapsuleOpening` Darken order, black, transparency 0.5, position (0,-36) as `PromptSelection.luau:364`; never ZIndex 50.)
**4. Quests page.** New `Pages/Quests/init.luau`: `return function(props) return c(OpenableMenu, { TitleText = "Quests", TitleColor = Styles.GREEN, Pages = { { Key = "Daily", Label = "Daily Quests", Content = c(DailyQuests, { Quests = props.Quests }) } }, OnClose = function() props.ClosePage() end }) end` (Shop model; STYLE 4.1 says do not forget `OnClose`). `props.Quests` exists only so Part B and the story can mount it in edit mode.
**5. Quests tab content.** New `Pages/Quests/DailyQuests.luau` = `QuestCard.luau` with the card removed: keep `PREVIEW_QUESTS`, `checkFreeRerolls`, `QuestActionButton`, `QuestRow`, the fetch/claim/reroll hooks and the `QuestsUpdated` subscription verbatim. Drop: the green header and its collapse toggle (`isExpanded`), the OFFWHITE card frame, `UICorner`/`UIStroke`, `Position (10,48)`, `Size 230`, `ZIndex 10`, the divider-free `UIPadding` card padding. Render, per STYLE 4.1a/2.5: tab title `Daily Quests` (Currency title spec), then a `ScrollingFrame` (STYLE 2.5) holding `QuestRow`s with the existing 1 px `GRAY` dividers. Empty list when running: a `GREEN` title-style label at 0.4 transparency `You don't have any quests!` (STYLE 2.5) instead of `return nil`. Row geometry: replace fixed pixel offsets and `TextSize` with `usePx` so rows scale with the menu (a 230 px card inside a ~480 px content area would look tiny, and small size was Jack's DEC-038 complaint): title text `px(18)`, reward pill `px(110)` x `px(24)` with `MaxTextSize px(14)`, progress bar height `px(24)` with label `px(15)`, action button `px(100)` x `px(30)` with `MaxTextSize px(18)`, text column width = row width minus action width minus gap. Same tokens (`GREEN_DEEP` titles, `GOLD_MID`/`GOLD_DEEP` pill, `GRAY` track, `GREEN`/`GREEN_LIGHT` fill, `GREEN` Claim, `GOLD_MID` 20 BB reroll, `GREEN_LIGHT` Free). Strings unchanged: `Claim`, `Claimed`, `Free`, `{REROLL_COST_BOBABUCKS} BB`, `+N BB · +N XP`. Keep the QUESTCARD-FIX anchors (action button right-aligned, not over the bar or `n / m` label).
**6. Remove the HUD card.** In `Hud/init.luau` delete `local QuestCard = require(script.QuestCard)` and the `QuestCard = c(QuestCard, {})` element. Delete `Hud/QuestCard.luau`.
**7. Quests button.** In `BottomLeft.luau` add, directly after `Daily` and copying its component and prop set (`NormalButton`, `Size = BUTTON_SIZE`, `Color`, `Text`, `OnClick`, `LayoutOrder`): `Quests = c(NormalButton, { Icon = "", Size = BUTTON_SIZE, Color = Styles.GREEN_MID, Text = "Quests", OnClick = function() props.SetCurrentPage(UI.Pages.Quests) end, LayoutOrder = 4 })`. Renumber `Points` to 5 and `Bucks` to 6. `UI.Pages.Quests` resolves like `UI.Pages.Recipes` at line 363. Daily keeps its controller call. No indicator, no badge.
**8. Mobile (state, no new code).** The Daily dialog and Quests page both render inside `Page` (0.8 x 0.8 frame, `UIScale` 0.8, effective 0.64 of the screen) with the `OpenableMenu` `AspectRatio` 1.347, the same scaling as Shop, Inventory and Menu. All text is `TextScaled`; pixel sizes use `usePx` (reference 1280x832, floor 0.75). There is no phone layout in the codebase (STYLE 2.2). So on phones both menus are as large as the Shop: much bigger than the old 230 px HUD card, but on a portrait phone width-bound at 0.64 of the screen width. Do not add a phone branch. Part B records the real aspect ratios captured.
**9. Stories.** Add `Stories/DailyRewards.story.luau` (mounts `DailyRewardsDialog` with a fixed Day 3 `Status` built from `DailyRewardConfig.REWARDS`) and `Stories/Quests.story.luau` (mounts `Pages/Quests` with three `QuestEntry` rows), both modelled on `Shop.story.luau`.
**10. Gate** (Hard constraints) on every file in Part A scope. Report the findings diff versus before.

## Done when
- `DailyRewardsDialog.luau` renders only `Page > OpenableMenu` content built from existing components and tokens; no backdrop element; no `Color3.fromRGB`; no Knit or handler behavior changed; the countdown state no longer sits above `Page`.
- `Hud/init.luau` and `QuestCard.luau` have no quest card; `Pages/Quests` exists; the Quests button sits after Daily and before Points.
- All amounts come from config (30/45/60/60/90/120/180, x2 VIP; reroll 20 BB).
- Gate shows no new findings in changed files; `rojo build` succeeds.
- Part B captures exist and are listed in evidence.md with the "new visual elements" list reading "none" (or each exception named).

## Part B: Lens re-capture (Studio: YES, exclusive; edit mode only)
Runs after Part A passes and Prime has the new source in Studio. Never start Play, never run TestEZ (DEC-019); if `get_studio_state` shows Play, STOP. No saves, no script edits by Lens.
1. **Source freshness.** Rojo serve is not assumed. Prime confirms Studio holds the Part A source (Rojo live-sync connected, unsaved) before this step. Lens checksums (djb2, CR stripped) the changed modules under `ReplicatedStorage.Shared.UI` against the repo (`DailyRewardsDialog`, `Pages/Quests/init`, `Pages/Quests/DailyQuests`, `Hud/init`, `BottomLeft`) and notes that Studio's require cache can serve old modules (M4-UI-APPROVAL); a difference means STOP and report BLOCKED. `QuestCard` must be absent.
2. **Mounts (copy M4-UI-REF's, record them).** App-gui mount for the Quests page and BottomLeft: `ScreenGui` with `ResetOnSpawn=false`, `ZIndexBehavior=Sibling`, `IgnoreGuiInset=true`, default DisplayOrder, wrapper `Pane(full) > Pages > Page` as in `App.luau` (BottomLeft as a HUD sibling with `CurrentPage=nil`, `SetCurrentPage=noop`). Dialog mount for Daily: a ScreenGui named `Priority`, `DisplayOrder=100`, `ResetOnSpawn=false`, `ZIndexBehavior=Sibling`, `IgnoreGuiInset=false` (the real `AppDialogs.luau:252-256` host, which hosts the dialog), mounting the dialog module directly (it wraps its own `Page`). One state per run; each run: mount, wait ~1 s, `screen_capture`, unmount, `Destroy`. Springs do not advance in edit mode (panel sits at UIScale 0.8), so record that.
3. **Captures, saved as jpg to `tasks/REVIVAL-001/M4-UI-DAILY-REDO/captures/`:**
   - `a-daily-day3-canclaim.jpg`: `Status = { CanClaim=true, DayToClaim=3, CurrentStreak=2, SecondsUntilNextClaim=0, Expired=false, IsVIP=false, DataLoaded=true, Reward=REWARDS[3] }`.
   - `b-daily-day3-vip.jpg`: same with `IsVIP=true`; amounts 60/90/120/120/180/240/360.
   - `c-daily-claimed.jpg`: `CanClaim=false, DayToClaim=4, CurrentStreak=3, SecondsUntilNextClaim=43200, IsVIP=false`; disabled "Next in 12:00:00" button.
   - `d-quests-menu.jpg`: Quests page with 3 `QuestEntry` built from `QuestConfig` (template `Targets`, `BobaBucks`, `XP` at one index, `GetQuestTitle`): one mid-progress (1 of target, shows the 20 BB reroll), one Completed (Claim), one Claimed. Optional `d2-quests-empty.jpg` with `Quests = {}` is not capturable in edit mode (empty branch needs `IsRunning`); skip and note.
   - `e-bottomleft-daily-quests.jpg`: `BottomLeft` showing Daily and Quests buttons. Check the taller column does not collide with anything.
4. **Per capture, record in evidence.md:** ScreenGui properties used, panel on-screen size, whether any dim or overlay is present, and an explicit check that no element draws over the panel. Compare each against M4-UI-REF 01/04 (frame, title tab, X, tab column, fonts).
5. **List every visual element not from existing tokens/components** (expected "none"; list the lone side tab, the `✓` text and the GOLD_MID current row as "existing token, new combination" for Jack).
6. **Cleanup check:** `_LensPreview` and the temporary `Priority` mount gone; StarterGui and ReplicatedStorage child counts unchanged (1 and 7 before the Rojo sync, or note the sync delta); nothing saved.

## STOP-AND-ASK
- Q16, Q17 or Q18 unanswered: do not start; report BLOCKED to Prime (Prime asks Jack, DEC-008).
- Any element that no existing component or token covers (a pill, an icon, a card, a new radius or colour, a claim indicator): stop and report with the file and what was searched; do not build the closest thing.
- If `OpenableMenu` with one tab renders badly in the story/edit mount in a way that needs a prop or size change to `OpenableMenu`: stop (shared component, not in write scope).
- If a Daily or Quests behavior would change (amounts, reroll cost, claim flow): stop.
- Part B: Play mode, stale or missing Part A source in Studio, a module that cannot mount without Knit, or any need to edit a script or save: BLOCKED.

## Evidence
`tasks/REVIVAL-001/M4-UI-DAILY-REDO/evidence.md` (RUNBOOK step 5): gate output (diff of findings), the Part B captures list and checks, and the "Test for Jack" list below. Note for Jack: with the HUD card gone, nothing on screen tells a player a quest is claimable or a daily reward is waiting (the join auto-open covers the first claim only); an indicator would be a new visual and is a separate ask.

## Test for Jack (Play, his Studio)
- Join with a claim available: Daily opens by itself as a menu; close with X; no screen dim anywhere; Shop and Daily look like one family.
- Daily button: opens the menu; claim Day N; toast and amounts match (30/45/60/60/90/120/180, x2 VIP); button turns to the disabled countdown; the dialog does not re-bounce every second while it counts down.
- Quests button next to Daily opens the Quests menu; pressing it again closes it; Daily and Quests menus open without leaving the HUD card on screen.
- Quests: progress, Claim, Claimed, 20 BB reroll (and Free with the pass), "Not enough Boba Bucks" toast when broke; empty state reads "You don't have any quests!".
- Mobile: Studio device emulator, landscape and portrait, check text legibility and the taller bottom-left column.

## Jack's answers (Prime fills before dispatch)
Q16 = A   Q17 = A (none: delete the Backdrop)   Q18 = A   (DEC-041, Jack 2026-10-19)
