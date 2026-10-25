# UI-TICKET-DAILY-MENU: larger order ticket in the upper right; Daily Rewards becomes a Menu tab
Model: sonnet (Mason, Part A, Studio: no; Lens, Part B, Studio: YES exclusive)   Depends on: DEC-050 and Jack's answers to Q27-Q31 below   Size: M

## Goal
- (1) The order ticket stack (`TicketStack`, up to 2 tickets) is MUCH larger and sits on the upper right of the screen.
- (2) The `Daily` button leaves the bottom-left stack. Daily Rewards is a tab inside the existing Menu page (`Pages/Menu`, `OpenableMenu`). DEC-045 A content (streak row, claim, countdown, amounts) is unchanged and not duplicated.
- No server code, no economy, no new colour/radius/font/component. The only new thing is the ticket SIZE, as Jack requested (DEC-013 exception limited to size).

## Verified facts
- `Hud/init.luau:68-86`: `TicketStack` Frame, AnchorPoint (1,1), Position (0.99,0.92), Size offset 190 x auto, ZIndex 10, UIListLayout vertical padding 10, holds `OrderTicket` slot 1 and slot 2.
- `OrderTicket.luau`: every size and text is fixed pixels (text 13/15 `:89,121,262`, header 28 px `:448`, radius 6). Width 190 comes from the stack, not the ticket (stacked ticket Size is `(1,0)`, `:427`). Phones start collapsed to the header line (`canCollapse = TouchEnabled`, `:206-207`); tap toggles. Height auto.
- `ShiftCard.luau:113-122`: AnchorPoint (1,0), Position (0.99,0.14), Size (0.2,0.3) with `UISizeConstraint` Min 190x160 / Max 300x250. At 844x390 it is 190x160 (y 55-215 px); at 1280x832 it is 256x250 (y 116-366). Renders `nil` when no shift (`:73,84`).
- `CafeRating.luau:73-82`: top centre, y 0.115, 0.2 x 0.08 (Min 190x38). `OrderQueue`: bottom centre (0.5,0.92).
- `Pane.luau:137` already supports a `Scale` prop (UIScale); `usePx` scale is 1.0 at 1280x832 and clamps to 0.75 on the 844x390 phone frame (`usePx.luau:12-35`).
- `BottomRight.luau:24-27,40`: Quests mount is anchored by `JUMP_BUTTON_CLEARANCE = 196` from the right and 0.981 down; it is positioned by the JUMP zone (DEC-049), not by the ticket.
- `BottomLeft.luau:368-382` Daily button (LayoutOrder 3, calls `DailyRewardController:OpenDailyRewards()`); Points `:393` is 4, Bucks `:405` is 5. Quests is already gone from this stack.
- `Pages/Menu/init.luau`: `OpenableMenu` with `Pages = { {Key, Label, LayoutOrder, Content = {Page = c(Comp, {})}} }`, 7 tabs today. `OpenableMenu.luau:64,74` supports `DefaultPage` (a Key); the first page is default. Menu is opened from `TopBar.luau:191-195` via `SetCurrentPage(Pages.Menu)`; `App.luau:35-58` passes `Args` to a page and toggles closed when the same page is passed again.
- `DailyRewardsDialog.luau:58-375`: `DailyRewardsMenu` holds all hooks (status fetch, countdown, claim) then builds `rewardsTab` (`:308`) and wraps it in `OpenableMenu` titled "Daily Rewards" with ONE tab and `OnClose` (`:368-375`). The exported component adds the `Page` wrapper and `closeFnRef` (`:378-402`). So the body and the logic live in the same function as the menu shell.
- `DailyRewardController.luau:14-47`: `OpenDailyRewards` opens the `DailyRewardsDialog` through `DialogController`; `KnitStart` polls `GetRewardStatus` and auto-opens it when `status.CanClaim` (join prompt). `BottomLeft` is the only other caller.
- Not in Rojo and untouched: place-authored content (`workspace.Assets`, `Ordering System`, `SelectorModels`, `Networking`, `SFX`).

## PENDING JACK (Prime asks; Mason does not start until answers are in decisions.md and pasted at the bottom)
**Q27 Ticket size.**
- **A (recommended).** Keep the ticket code; wrap `TicketStack` contents in a UIScale (existing `Pane` `Scale` prop) of `px.scale(1.6)`: 304 px wide at 1280x832 (24% of width), 228 px wide at 844x390 (27%; scale clamps to 1.2). Text becomes 21/24 desktop, 16/18 phone, header 45/34 px. Fonts, colours, radii unchanged; layout identical. Phone default stays collapsed (header only), so two tickets use about 80 px; expanded, one ticket is about 150-170 px (Lens measures).
- B. Fixed 1.75 desktop / 1.3 phone: larger and harder on the 390 px height with two expanded tickets (about 420 px, taller than the screen).
- C. Rewrite OrderTicket to `usePx` sizes. Cleaner, but touches ~40 lines in a prototype file; not recommended.

**Q28 Placement vs ShiftCard (both upper right).**
- **A (recommended).** One right-hand column, TICKETS ON TOP: `TicketStack` anchored (1,0) at (0.99,0.14) growing downward; `ShiftCard` directly below it (same right edge, 10 px gap) instead of at 0.14. Implement with a shared container Frame (anchor (1,0), Position (0.99,0.14), UIListLayout, tickets LayoutOrder 1, ShiftCard LayoutOrder 2); ShiftCard keeps its internals and gets a fixed size equal to its current clamped one. No overlap by construction; both are still right-side and upper. Risk: on 844x390 with two collapsed tickets the ShiftCard spans about y 135-295, which is inside the jump zone (x >= 0.75, y >= 0.6 = 234). Lens measures; if it overlaps, fall back to B.
- B. Tickets in their own column immediately LEFT of ShiftCard (ticket right edge = ShiftCard left edge - 12 px), top at 0.22 (below CafeRating). No vertical push, keeps the jump zone clear; on phone ticket x about 414-642, which is between the thumb zones.
- C. ShiftCard unchanged at 0.14-0.44 and tickets below it. Not recommended: that is mid-right, and expanded tickets run into the jump zone.

**Q29 Quests clearance.** The ticket leaves the bottom right. Recommended: NO change to `BottomRight` (offset stays set by the jump zone, DEC-049). Alternative: restore the corner position; rejected, jump button overlap.

**Q30 Daily tab placement and body.**
- **A (recommended).** New Menu tab `Daily Rewards` as LayoutOrder 2 (after Food Menu); the other five tabs renumber 3-8; `Food Menu` stays the default tab. Body is the DEC-045 A rewards body, extracted (below), not copied.
- B. Daily as the first and default tab (Menu would open on Daily every time).
- Note: 8 tabs in the side bar; Part B must show they fit (desktop and phone). If they do not, STOP and ask (no new scroll pattern).

**Q31 Join auto-open when `CanClaim`.**
- **A (recommended). Keep the standalone `DailyRewardsDialog` for the join auto-open only.** It uses the same extracted body; the Daily BUTTON entry is gone, the Menu tab is the manual entry. Zero new plumbing, no risk of toggling a page shut, no controller-to-App bridge.
- B. Auto-open the Menu on the Daily tab. Needs a controller-to-Hud signal and `SetCurrentPage(Pages.Menu, "Daily")`, with `Menu` reading `props.Args[1]` as `DefaultPage`; must not call SetCurrentPage when a page is already open (App toggles it shut). More moving parts and races with Hud mount.
- No claimable indicator (badge/dot) on the Menu button or tab: that is a new visual; add only if Jack asks. With A the join prompt remains the notification.

## Files to change
Part A (Mason):
- `src/shared/UI/Components/Core/Hud/init.luau` (TicketStack scale and anchor; right column per Q28; ShiftCard mounting)
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau` (only if Q28 A/B needs its Position/Size changed to fit the column)
- `src/shared/UI/Components/Core/Hud/BottomLeft.luau` (delete Daily `:368-382`; Points to 3, Bucks to 4; drop the now-unused Knit `DailyRewardController` lookup if unused elsewhere)
- `src/shared/UI/Components/Dialogs/DailyRewardsBody.luau` (NEW; hooks and `rewardsTab` moved out of `DailyRewardsMenu`, props `{ Status }`, returns the rewards Frame; all logic, strings, sounds unchanged)
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` (`DailyRewardsMenu` becomes `OpenableMenu` + `c(DailyRewardsBody)`; exported Page wrapper unchanged)
- `src/shared/UI/Pages/Menu/Daily.luau` (NEW; thin: `return function() return c(DailyRewardsBody, {}) end`; fetches its own status on mount)
- `src/shared/UI/Pages/Menu/init.luau` (add Daily tab, renumber)
- `src/shared/UI/Stories/DailyRewards.story.luau` (still mounts the dialog; only touch if the require path changes)
Delete: none. Not touched: any server file, `DailyRewardController` (Q31 A), `DialogController`, `OpenableMenu`, `Page`, `Styles`, `OrderTicket` (Q27 A), `BottomRight` (Q29), config files.

## Steps
1. After Q27-Q31, extract `DailyRewardsBody` (move, do not edit logic); update `DailyRewardsDialog`; confirm the dialog still renders identically.
2. Add `Pages/Menu/Daily.luau` and the tab; check `OpenableMenu` Content shape matches (`Content = { Page = c(...) }`).
3. Remove the Daily button and renumber BottomLeft.
4. Rework the Hud right column per Q27/Q28.
5. Grep `src` for `OpenDailyRewards` and `"Daily"`: only the controller auto-open (and the story) remain.
6. Gate and `rojo build default.project.json -o <path outside repo>`; report findings diff.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio saves, no commits.
- Serve-path invariant: nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` / `RealOrderService`. This lane touches no server code; add none.
- Studio-authored content is not in Rojo and is not edited.
- DEC-013 / STYLE section 0: existing tokens and components only. The ticket SIZE change is the one exception, as Jack requested; no new colour, radius, font, asset, spring, badge, or backdrop. No literal `Color3.fromRGB`. If something is uncovered, STOP and report.
- Daily amounts and claim logic unchanged; never hand-type an amount.
- Gate on every changed or new Luau file: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. Per DEC-001, run `stylua` only on files without pre-existing drift; for drifted files run `gate` alone and show no new findings.

## Done when
- Ticket stack is clearly larger and in the upper right, no overlap with ShiftCard, CafeRating, TopBar, and (phone) no overlap with the thumbstick/jump zones; text legible at 844x390.
- BottomLeft has no Daily; Menu has a working Daily tab; Daily logic exists once.
- Gate shows no new findings; `rojo build` succeeds.

## Part B: Lens capture (Studio: YES, exclusive; edit mode only)
Runs after Part A passes and the Part A source is in Studio (Rojo live-sync, unsaved). Never Play or TestEZ (DEC-019); if `get_studio_state` shows Play, STOP. No saves, no script edits.
1. Freshness: djb2 (CR stripped) checksum `Hud/init`, `Hud/BottomLeft`, `Hud/ShiftCard`, `Pages/Menu/init`, `Pages/Menu/Daily`, `Dialogs/DailyRewardsBody`, `Dialogs/DailyRewardsDialog` under `ReplicatedStorage.Shared.UI` against the repo. Mismatch: STOP, BLOCKED.
2. Mounts: temporary `StarterGui._LensPreview` ScreenGui (`ResetOnSpawn=false`, `ZIndexBehavior=Sibling`, `IgnoreGuiInset=true`). Mount the real `Hud` (`CurrentPage=nil`, `SetCurrentPage=noop`) with two tickets and the ShiftCard visible (seed the same preview state used in M4-QUESTS-REDO; ticket and ShiftCard state seeding documented in evidence). Second run mounts `Pages/Menu` on its Daily tab. Springs do not advance in edit mode (note it). Per run: mount, wait ~1 s, `screen_capture`, unmount, `Destroy`.
3. Captures (jpg, `tasks/REVIVAL-001/UI-TICKET-DAILY-MENU/captures/`), each at TWO viewports: desktop (about 1280 x 832) and phone landscape (844 x 390):
   - `a-hud-tickets`: two tickets (one expanded, one collapsed on the phone run, or both expanded) plus ShiftCard.
   - `b-bottomleft`: stack without Daily.
   - `c-menu-daily`: Menu open on the Daily tab; also `d-menu-tabs` showing all 8 tabs fit.
4. `evidence.md`: viewports and mount properties; ticket on-screen pixel width/height at each viewport; overlap results versus ShiftCard, CafeRating, TopBar, Quests button, and the thumbstick (about 0-0.3 width, bottom 45%) and jump (about 0.75-1.0 width, bottom 40%) zones; whether the Quests button needed any change; new-visual list (expected: "ticket size only").
5. Cleanup: `_LensPreview` destroyed; StarterGui and ReplicatedStorage child counts unchanged; nothing saved.
6. Publish: read https://claude.ai/artifact/G98eDhF1Rz8dPusf5es5k4 first (Artifact `action: "read"`), then republish the same URL with the new desktop and phone captures added, keeping prior content.

## STOP-AND-ASK
- Any of Q27-Q31 unanswered: BLOCKED to Prime (DEC-008).
- 8 Menu tabs do not fit, or the column overlaps a thumb zone and neither fallback fixes it.
- Anything needing a change to `OpenableMenu`, `Page`, `OrderTicket` internals, or a server file.

## Test for Jack (Play, his Studio)
- Join: ticket stack top right, much larger, readable; ShiftCard clear of it; no Daily button in the bottom-left stack.
- Order a drink with and without level 5 (second ticket): both tickets stack cleanly, no overlap.
- Menu: Daily Rewards tab opens, shows the current day, Claim works and pays once, countdown ticks, closes with the Menu X.
- Fresh account / claimable day: join prompt appears (Q31 A) and still claims correctly; Menu Daily tab then shows "Next in ...".
- Mobile emulator (landscape and portrait): ticket legible, collapsed by default and expandable by tap, clear of thumbstick, jump and Quests button.

## Jack's answers (Prime fills before dispatch)
Q27 = A (1.6x ticket scale)   Q28 = A (one right column: tickets on top, ShiftCard below; Lens measures the jump-zone risk, fallback B)   Q29 = no Quests button change   Q30 = A (Daily as Menu tab 2, Food Menu default; Lens shows all 8 tabs fit)   Q31 = A (standalone dialog kept for join auto-open only)   (DEC-052)
