# M4-QUESTS-REDO: Quests return as a closed-by-default pop-up card; Quests button moves to the bottom right
Model: sonnet (Mason, Part A, Studio: no; Lens, Part B, Studio: YES exclusive)   Depends on: DEC-038, DEC-045, DEC-047, and Jack's answer to Q24 below   Size: S-M

## Goal
- The original DEC-038-approved QuestCard (green header, rows, reward pills, Claim / Reroll 20 BB / Claimed) comes back as a centred pop-up card: CLOSED by default, never always-on. Opened by the Quests button; closed by its own X or by tapping Quests again.
- Easy on mobile: finger-sized rows and buttons (>= 44 px effective touch targets), card stays clear of the thumbstick (bottom-left) and jump button (bottom-right).
- The interim `Pages/Quests` menu is gone. The Quests button leaves the bottom-left stack (DEC-047: too tall) and sits bottom right.
- Behavior, data and amounts unchanged: `QuestService` `GetQuests`, `ClaimQuest(i)`, `RerollQuest(i)`, `QuestsUpdated`; reroll cost from `QuestConfig.REROLL_COST_BOBABUCKS`; free-reroll check; InsufficientFunds toast.

## PENDING JACK (Prime asks; Mason does not start until the answer is in decisions.md and pasted at the bottom)
Facts (verified in source): `BottomRight.luau` is an empty mount, anchored (1,1) at (0.981,0.981), size 0.175 x 0.3, bottom-aligned vertical list, already rendered by `Hud/init.luau:42`; it is the obvious slot. But the bottom-right is shared: `TicketStack` (`Hud/init.luau`, anchor (1,1) at (0.99,0.92), 190 px wide, up to 2 stacked order tickets, ZIndex 10) sits directly above it, `ShiftCard` is top right (0.14-0.44), and Roblox's mobile jump button lives in the bottom-right corner (STYLE 2.2 lists thumbstick/jump overlap as UNVERIFIED). A button at the very corner of `BottomRight` would sit on the jump button on phones.
**Q24 Quests button slot.**
- **A (recommended).** Use the existing `BottomRight` mount, one `NormalButton`, shifted left of the jump button by a fixed pixel offset on the mount's Position X (about `-130` px from the right edge, so it clears the default jump button), bottom edge unchanged, fixed button row height equal to the BottomLeft row (`BUTTON_SIZE` scale in a 0.06-0.07 tall frame). Same component, same prop set as the Daily button, no new pattern; only the mount's Position changes (that file is in scope). Residual risk: it sits just under the ticket stack's bottom edge (0.92); Part B captures with two tickets and a phone viewport to verify no overlap. Mobile emulator check by Jack.
- B. Keep the exact `BottomRight` anchor (corner) and accept overlap with the jump button on phones. Not recommended.
- C. Right edge, between `ShiftCard` (ends 0.44) and `TicketStack`, vertically centred (about y 0.55). Clear of both thumb zones but it is not "bottom right" and is a new position.
Button style: text-only `NormalButton`, `Icon = ""`, `Color = Styles.GREEN_MID`, `Text = "Quests"` (Q18=A). No bottom-right context requires a change.

## Already built (verified)
- Original card: `git show 8c82ae9^:src/shared/UI/Components/Core/Hud/QuestCard.luau` (recover to the working tree with this command; it is the approved design). Header 28 px `GREEN`, "Daily Quests", `OFFWHITE` card, `UIStroke GREEN_DIM`, fixed 230 px width, `Position (10,48)`, `ZIndex 10`, collapse toggle `▲/▼`, returns `nil` when running with no quests. It was mounted at `Hud/init.luau` as `QuestCard`.
- Interim code to replace: `src/shared/UI/Pages/Quests/init.luau`, `src/shared/UI/Pages/Quests/DailyQuests.luau` (already holds the usePx-scaled rows and hooks, reuse as the source of row logic), `src/shared/UI/Stories/Quests.story.luau`, Quests button at `BottomLeft.luau:384-393` (LayoutOrder 4; Points 5, Bucks 6).
- Mount mechanism read: `App.luau` renders any ModuleScript from `SetCurrentPage` inside `Page` (0.8 x 0.8 pane, spring pop-in), is exclusive (one page at a time), and pressing the same HUD entry closes it. `Page.luau:55-67` restarts its spring whenever `PageContent` identity changes (the Daily re-bounce bug), and the close callback arrives through `OnClosing`. `Hud` is a sibling of `Pages` inside the App gui (`ZIndexBehavior = Sibling`); `TicketStack` is ZIndex 10. `Hud/init.luau` already receives `CurrentPage` and `SetCurrentPage`.
- Existing close control: `Buttons/CloseButton.luau` (used by `OpenableMenu.luau:125`). The card X uses it (no new icon).
- No backdrop dim: no existing menu or small panel dims (M4-UI-REF "Backdrop order per menu"); do not add one.

## Mount / toggle decision (fixed; do not use SetCurrentPage)
Quests is a small card, not a page: `SetCurrentPage` would close Shop/Inventory when Quests is tapped and requires a ModuleScript page registration. Instead:
- `Hud/init.luau` owns `questsOpen` state (`React.useState(false)`) and passes `{ QuestsOpen, OnToggleQuests }` to `BottomRight`, and renders the popup as the LAST child of the root Pane: `QuestPopup = if questsOpen then c(QuestCard, { OnClose = closeQuests }) else nil`. Last sibling plus `ZIndex = 20` on the popup's single outer Frame (above `TicketStack` 10; set ZIndex on this one sibling only, no inner ZIndex games, the Daily backdrop lesson).
- `QuestCard.luau` follows the Daily split (`DailyRewardsDialog` Step 1, `ButtonPrompt.luau:37-43`): outer exported component owns `closeFnRef` and returns `c(Page, { IsVisible = true, PageContent = c(QuestCardBody, { OnCloseRequested = handleClose }), OnClosing = function(cb) closeFnRef.current = cb end })`; `QuestCardBody` holds the fetch/claim/reroll state. The outer holds no changing state, so `PageContent` identity is stable and the spring plays once. `handleClose` = `closeFnRef.current()` then `task.wait(0.025)` then `props.OnClose()` (mirror `App.luau` `PAGE_SWAP_DELAY`; run in `task.spawn`). The same `handleClose` serves the X and the Quests button toggle.
- Toggle: Quests pressed while closed: if `props.CurrentPage ~= nil` call `props.SetCurrentPage(props.CurrentPage)` (App's own toggle closes the open page), then `setQuestsOpen(true)`. Pressed while open: close via the popup's `handleClose` (expose it with a ref from `Hud/init`, or use a `closeRequest` counter prop; Mason picks the simpler, no new visual). Also close the card when `CurrentPage` becomes non-nil (effect on `props.CurrentPage`), so Shop/Inventory/Menu and the card are never stacked.
- The card renders `nil` while closed, so nothing exists on screen and quest fetching starts on first open (the `GetQuests` fetch and `QuestsUpdated` subscription mount with `QuestCardBody`; confirm the claim-from-closed path is not needed: quests only change in `QuestService`, the card refetches on open).

## Card layout (existing tokens only; DEC-013)
- Outer Frame centred (`AnchorPoint (0.5,0.5)`, `Position (0.5,0.5)`) inside `Page`'s content, `OFFWHITE`, `UICorner 6`, `UIStroke GREEN_DIM 1` as the original. Width `px(330)` capped with `UISizeConstraint` `MaxSize` so it never exceeds 0.45 of screen width (phone landscape: a ~340 px card spans the middle, clear of thumbstick x <= ~0.3 and jump x >= ~0.75). Height `AutomaticSize.Y` capped by a `ScrollingFrame` body (STYLE 2.5) of max height 0.65 of the Page pane, so on a short phone screen the rows scroll and the card never reaches the bottom corners.
- Header: original 28 px `GREEN` bar scaled via `usePx` (min px(40)), "Daily Quests" in `OFFWHITE` left; the `▲/▼` collapse toggle is REMOVED and replaced by `CloseButton` on the right (no collapse state).
- Rows: original `QuestRow` content and tokens (`GREEN_DEEP` title, `GOLD_MID`/`GOLD_DEEP` reward pill, `GRAY` track, `GREEN`/`GREEN_LIGHT` fill, `GREEN` Claim, `GOLD_MID` "20 BB" reroll, `GREEN_LIGHT` Free, 1 px `GRAY` dividers). Reuse the `usePx` row geometry already in `Pages/Quests/DailyQuests.luau`, then raise it: the Claim/Reroll/Claimed button is >= 44 px EFFECTIVE (Page scales content, read `GOAL_SCALE` in `Page.luau`; if it is 0.8, author the button at `px(56)` height), row vertical padding >= `px(8)`, title text >= `px(16)`. Strings unchanged: `Claim`, `Claimed`, `Free`, `{REROLL_COST_BOBABUCKS} BB`, `+N BB · +N XP`. Keep the QUESTCARD-FIX anchors (action button right-aligned, not over the bar or `n / m`).
- Empty list while running: `You don't have any quests!` label (STYLE 2.5), not `nil`.
- No claimable badge or indicator on the Quests button (new visual; separate ask).

## Read (only these)
`AGENTS.md`; `docs/STYLE.md` sections 0, 1.1-1.10, 2.1-2.5, 3.5, 4.2; `decisions.md` DEC-013, DEC-038, DEC-039, DEC-041, DEC-045, DEC-047; `Core/Page.luau`, `Core/OpenableMenu.luau:100-140`, `Buttons/CloseButton.luau`, `Buttons/NormalButton.luau`, `Dialogs/DailyRewardsDialog.luau` (the split pattern), `Hud/init.luau`, `Hud/BottomRight.luau`, `Hud/BottomLeft.luau:240-421`, `Pages/Quests/DailyQuests.luau`, `src/shared/UI/App.luau`, `Configuration/QuestConfig.luau` (read only), `Hooks/usePx.luau`, the recovered original `QuestCard.luau`.

## Write scope
Part A (Mason):
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (restore from `8c82ae9^`, then adapt per the layout and mount sections; this file is new again)
- `src/shared/UI/Components/Core/Hud/init.luau` (state, popup mount, CurrentPage effect, pass props to BottomRight)
- `src/shared/UI/Components/Core/Hud/BottomRight.luau` (Quests button; mount Position per Q24)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (delete the Quests button; Points back to 4, Bucks to 5)
- `src/shared/UI/Pages/Quests/init.luau`, `src/shared/UI/Pages/Quests/DailyQuests.luau` (DELETE; fold their row code into `QuestCard.luau` first, then delete the `Pages/Quests` folder)
- `src/shared/UI/Stories/Quests.story.luau` (re-point to mount `QuestCard` with three `QuestEntry` rows; keep `Shop.story.luau` as the model)
Part B (Lens): `tasks/REVIVAL-001/M4-QUESTS-REDO/` only (captures/, evidence.md). Studio: a temporary `StarterGui._LensPreview` ScreenGui, destroyed before finishing.
Not touched: `QuestService`, any Knit service or controller, any Configuration file, `Styles.luau`, `Page`, `OpenableMenu`, `CloseButton`, `NormalButton`, `App.luau`, `AppDialogs`, `DailyRewardsDialog`, `DailyRewardController`, `CustomerService`, `RealOrderService`, place-authored content.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio saves.
- Serve-path invariant: this lane must not touch `CustomerService:_onServeTriggered` or `RealOrderService` payout; nothing may yield between the serve guards and the payout. (Server files are not in scope; do not add any server edit.)
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited.
- DEC-013 / STYLE section 0: only existing tokens, components, patterns. No new colour, radius, font, asset id, spring, shadow, gradient, component, backdrop dim or badge. No literal `Color3.fromRGB`. Anything uncovered: STOP and report.
- Economy untouched; never hand-type an amount.
- Gate on every changed or new Luau file, running stylua only on files without pre-existing drift (DEC-001); for drifted files run `gate` alone and show no new findings: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. Also `rojo build default.project.json -o <path outside the repo>`.

## Steps
1. After Q24 is answered, recover the original (`git show 8c82ae9^:...QuestCard.luau > src/shared/UI/Components/Core/Hud/QuestCard.luau`).
2. Adapt `QuestCard.luau`: split into outer `Page` wrapper + `QuestCardBody`; remove `isExpanded` and the toggle, add `CloseButton`; centre the card; scrollable body; scale rows with `usePx` using the geometry in `Pages/Quests/DailyQuests.luau`; empty-state label.
3. `Hud/init.luau`: add `questsOpen`, popup child (last, ZIndex 20), CurrentPage effect, toggle handler (Mount/toggle section).
4. `BottomRight.luau`: add `Quests` `NormalButton` per Q24; `BottomLeft.luau`: remove Quests button, renumber.
5. Delete `Pages/Quests/`; update `Quests.story.luau`.
6. Grep `src` for `Pages.Quests`, `UI.Pages.Quests` and `DailyQuests`: no remaining references.
7. Gate and `rojo build`; report the findings diff versus before.

## Done when
- Quest card is absent on load and after a rejoin; opens only from the Quests button; closes by its X or the button; Shop/Inventory/Menu never stack with it.
- No `Pages/Quests`, no Quests entry in `BottomLeft`; Quests button in the Q24 slot, `GREEN_MID`, text only.
- Rows and action buttons >= 44 px effective; card width/height keep clear of the bottom corners at phone aspect ratios.
- Quest behavior and strings identical; gate shows no new findings; `rojo build` succeeds.

## Part B: Lens capture (Studio: YES, exclusive; edit mode only)
Runs after Part A passes and Prime has the Part A source in Studio (Rojo live-sync, unsaved). Never start Play or run TestEZ (DEC-019); if `get_studio_state` shows Play, STOP. No saves, no script edits.
1. Source freshness: djb2 (CR stripped) checksum `Hud/init`, `Hud/QuestCard`, `Hud/BottomRight`, `Hud/BottomLeft` under `ReplicatedStorage.Shared.UI` against the repo (Studio's require cache can serve old modules; a mismatch means STOP, BLOCKED). `Pages/Quests` must be absent.
2. Mounts: temporary `StarterGui._LensPreview` ScreenGui, `ResetOnSpawn=false`, `ZIndexBehavior=Sibling`, `IgnoreGuiInset=true`, mounting the real `Hud` (with `CurrentPage=nil`, `SetCurrentPage=noop`) so the BottomRight button, TicketStack and the popup are all present, plus a second run mounting `QuestCard` directly. Springs do not advance in edit mode; record that. Per run: mount, wait ~1 s, `screen_capture`, unmount, `Destroy`.
3. Captures (jpg, `tasks/REVIVAL-001/M4-QUESTS-REDO/captures/`), each at TWO viewports, desktop (about 1280 x 832) and a phone-size viewport (about 844 x 390 landscape; also 390 x 844 portrait if the viewport can be set):
   - `a-closed-bottomright`: Hud only, quest card closed, Quests button visible at bottom right, two tickets showing if mountable.
   - `b-quests-open`: card open with 3 `QuestEntry` built from `QuestConfig` (one mid-progress with the 20 BB reroll, one Completed with Claim, one Claimed).
   - `c-bottomleft`: confirms the bottom-left stack is shorter (Clock Out, Recipe Book, Daily, Points, Bucks).
4. evidence.md records: viewports and mount properties, card on-screen pixel size, measured Claim button height in effective px, whether the card or the Quests button overlaps the TicketStack, the bottom-left or bottom-right thumb zones (state zones used: left thumbstick about 0-0.3 width, bottom 45%; jump about 0.75-1.0 width, bottom 40%), any dim/overlay (expected none), and the new-visual list (expected "none"; list "pop-up card on Page", "CloseButton in card header" as existing component, new combination).
5. Cleanup: `_LensPreview` destroyed; StarterGui and ReplicatedStorage child counts unchanged; nothing saved.
6. Publish: read artifact https://claude.ai/artifact/G98eDhF1Rz8dPusf5es5k4 first (Artifact `action: "read"`), then republish the same URL with the new captures added (desktop and phone-size), keeping prior content.

## STOP-AND-ASK
- Q24 unanswered: BLOCKED to Prime (DEC-008).
- Any element or position no existing component/token covers: stop and report with what was searched.
- If `Page` or `CloseButton` needs a prop change: stop (shared components, out of scope).
- If a quest behavior, amount or string would change: stop.

## Test for Jack (Play, his Studio)
- Join: no quest card on screen; Quests button at the bottom right; bottom-left stack is shorter.
- Tap Quests: card pops in centred; tap Quests again: it closes; X closes it; it does not re-bounce while progress ticks.
- Open Shop or Inventory while the card is open: the card closes (and vice versa), never stacked.
- Quests: progress, Claim, Claimed, 20 BB reroll (Free with the pass), "Not enough Boba Bucks" toast when broke, "You don't have any quests!" when empty.
- Mobile (device emulator or phone, landscape and portrait): Quests button reachable and not on the jump button; card clear of thumbstick and jump; rows and buttons easy to tap; list scrolls if tall; with two order tickets showing, the button does not sit on them.

## Jack's answers (Prime fills before dispatch)
Q24 = A (DEC-048)
